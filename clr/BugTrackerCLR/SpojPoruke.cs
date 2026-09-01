using System;
using System.Data.SqlTypes;
using System.IO;
using System.Text;
using Microsoft.SqlServer.Server;

// Agregatna funkcija za zahtev 8. Spaja poruke gresaka u jedan string
// razdvojen sa " | ". U bazi je registrovana kao impl.SpojPoruke, a QA
// aplikacija je vidi kroz spec.vw_SAZETAK_PROJEKATA pa api_qa.SAZETAK_PROJEKATA,
// na ekranu "sazetak po projektu" gde se stanje celog projekta vidi u jednom
// redu bez otvaranja svake greske posebno.
// STRING_AGG postoji od 2017 i radi isti posao, ali zahtev trazi bas CLR UDA
// sa sve cetiri metode i sa IBinarySerialize.
// Ono sto ovde treba razumeti je zivotni ciklus agregata. Init se zove jednom
// na pocetku svake grupe, Accumulate jednom po redu te grupe, Terminate jednom
// na kraju i on vraca rezultat. Merge se zove samo ako server racuna agregat
// paralelno, da spoji delimicna stanja - mozda se nikad ne pozove, ali mora
// da postoji jer se agregat inace ne moze ni registrovati.

[Serializable]
[SqlUserDefinedAggregate(
    // UserDefined jer stanje nosi StringBuilder, dakle promenljivu duzinu.
    // Native bi radio samo za prosta polja fiksne velicine. I bas UserDefined
    // je ono zbog cega moram da implementiram IBinarySerialize.
    Format.UserDefined,

    IsInvariantToNulls      = true,   // NULL ne menja rezultat, preskacemo ga
    IsInvariantToDuplicates = false,  // duplikati MENJAJU rezultat (kao SUM, ne kao MAX)
    IsInvariantToOrder      = false,  // redosled redova menja rezultat
    IsNullIfEmpty           = true,   // prazna grupa -> NULL, ne prazan string

    // -1 znaci do 2GB i sme se navesti samo uz UserDefined. da sam stavio neki
    // konkretan broj, npr. 8000, duzi rezultati bi bili tiho odseceni
    MaxByteSize             = -1,

    Name = "SpojPoruke")]
public struct SpojPoruke : IBinarySerialize
{
    private const string RAZDVAJAC = " | ";

    // StringBuilder a ne obican string - spajanje stringova u petlji pravi nov
    // objekat pri svakom koraku, O(n^2). ovde se pise u isti bafer.
    private StringBuilder bafer;

    // da razdvajac ne stoji ispred prve poruke, i da prazna grupa vrati NULL
    private bool prazan;

    public void Init()
    {
        bafer = new StringBuilder();
        prazan = true;
    }

    public void Accumulate(SqlString poruka)
    {
        // SqlString zna za NULL baze podataka (tri stanja: tekst, prazno, NULL),
        // zato .IsNull a NE == null
        if (poruka.IsNull)
            return;

        string tekst = poruka.Value.Trim();
        if (tekst.Length == 0)
            return;

        if (!prazan)
            bafer.Append(RAZDVAJAC);

        bafer.Append(tekst);
        prazan = false;
    }

    public void Merge(SpojPoruke drugi)
    {
        if (drugi.prazan)
            return;

        if (!prazan)
            bafer.Append(RAZDVAJAC);

        bafer.Append(drugi.bafer.ToString());
        prazan = false;
    }

    public SqlString Terminate()
    {
        if (prazan)
            return SqlString.Null;   // usaglaseno sa IsNullIfEmpty = true

        return new SqlString(bafer.ToString());
    }

    // Stanje agregata ne zivi samo u memoriji jedne niti - server ga prosledi
    // drugoj niti, ili ga privremeno spusti na disk ako ponestane memorije,
    // pa mora da zna kako da ga pretvori u bajtove i nazad. Zato ove dve.
    // Write i Read moraju pisati i citati iste stvari istim redom; ako se
    // razidju, stanje se tiho pokvari, bez ijedne poruke o gresci.

    public void Write(BinaryWriter pisac)
    {
        pisac.Write(prazan);                                            // 1. bool
        pisac.Write(bafer == null ? string.Empty : bafer.ToString());   // 2. string
    }

    public void Read(BinaryReader citac)
    {
        prazan = citac.ReadBoolean();                    // 1. bool
        bafer  = new StringBuilder(citac.ReadString());  // 2. string
    }
}
