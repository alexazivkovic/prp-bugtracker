using System.Data;
using ApplicationQA.Model;
using Microsoft.Data.SqlClient;

namespace ApplicationQA.Podaci;

// Sloj pristupa podacima QA aplikacije. Ista ideja kao u DEV aplikaciji, samo
// sto ovde nema nijedne metode koja menja podatke - uloga DataProviderQA ima
// pravo citanja i izvrsavanja iskljucivo nad semom api_qa, a nad api_dev,
// spec i impl joj je sve izricito odbijeno.
public sealed class DataProviderQA : IDisposable
{
    private readonly SqlConnection _veza;
    private readonly string _lozinkaUloge;

    public DataProviderQA(string vezniString, string lozinkaUloge)
    {
        _veza = new SqlConnection(vezniString);
        _lozinkaUloge = lozinkaUloge;
    }

    // Aplikaciona uloga vazi za sesiju pa veza ostaje otvorena dok aplikacija
    // radi; iz istog razloga je u veznom stringu Pooling=False.
    public string Prijava()
    {
        _veza.Open();
        using (var cmd = new SqlCommand("sp_setapprole", _veza) { CommandType = CommandType.StoredProcedure })
        {
            cmd.Parameters.AddWithValue("@rolename", "DataProviderQA");
            cmd.Parameters.AddWithValue("@password", _lozinkaUloge);
            cmd.ExecuteNonQuery();
        }
        using var ko = new SqlCommand("SELECT SUSER_SNAME() + N' -> ' + USER_NAME();", _veza);
        return (string)ko.ExecuteScalar();
    }

    private SqlCommand Procedura(string ime)
        => new SqlCommand(ime, _veza) { CommandType = CommandType.StoredProcedure };
    private SqlCommand Upit(string sql) => new SqlCommand(sql, _veza);
    private static string Tekst(SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);

    public List<PregledProjekta> UcitajProjekte()
    {
        var lista = new List<PregledProjekta>();
        using var cmd = Upit(@"SELECT Id, NazivProjekta, Verzija, UkupnoGresaka, Nereseno, Kriticnih
                               FROM api_qa.PREGLED_PROJEKATA ORDER BY Id;");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new PregledProjekta
            {
                Id = r.GetInt32(0), Naziv = r.GetString(1), Verzija = r.GetString(2),
                UkupnoGresaka = r.GetInt32(3), Nereseno = r.GetInt32(4), Kriticnih = r.GetInt32(5)
            });
        return lista;
    }

    // zove se ime koje dokumentacija trazi u zahtevu 12
    public List<RedMatrice> UcitajMatricu(int? idProjekta)
    {
        var lista = new List<RedMatrice>();
        using var cmd = Procedura("api_qa.upr_MatricaGresaka");
        cmd.Parameters.AddWithValue("@idProjekta", (object)idProjekta ?? DBNull.Value);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new RedMatrice
            {
                IdProjekta = r.GetInt32(0), NazivProjekta = r.GetString(1), Verzija = r.GetString(2),
                Kriticnih = r.GetInt32(3), Visokih = r.GetInt32(4), Srednjih = r.GetInt32(5),
                Niskih = r.GetInt32(6), Informativnih = r.GetInt32(7), Ukupno = r.GetInt32(8)
            });
        return lista;
    }

    public List<OtvorenaGreska> UcitajOtvorene()
    {
        var lista = new List<OtvorenaGreska>();
        using var cmd = Upit(@"SELECT Id, NazivProjekta, Poruka, Ozbiljnost, OpisOzbiljnosti,
                                      DatumPrijave, StatusGr, BrojKomentara, DanaOtvorena
                               FROM api_qa.OTVORENE_GRESKE ORDER BY Ozbiljnost, DanaOtvorena DESC;");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new OtvorenaGreska
            {
                Id = r.GetInt32(0), NazivProjekta = r.GetString(1), Poruka = r.GetString(2),
                Ozbiljnost = r.GetInt32(3), OpisOzbiljnosti = r.GetString(4),
                DatumPrijave = r.GetDateTime(5), Status = r.GetString(6),
                BrojKomentara = r.GetInt32(7), DanaOtvorena = r.GetInt32(8)
            });
        return lista;
    }

    public List<SazetakProjekta> UcitajSazetak()
    {
        var lista = new List<SazetakProjekta>();
        using var cmd = Upit(@"SELECT IdProjekta, NazivProjekta, BrojGresaka, SvePoruke
                               FROM api_qa.SAZETAK_PROJEKATA ORDER BY IdProjekta;");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new SazetakProjekta
            {
                IdProjekta = r.GetInt32(0), NazivProjekta = r.GetString(1),
                BrojGresaka = r.GetInt32(2), SvePoruke = Tekst(r, 3)
            });
        return lista;
    }

    public List<AktivnostAutora> UcitajAktivnost()
    {
        var lista = new List<AktivnostAutora>();
        using var cmd = Upit(@"SELECT Autor, BrojKomentara, PoslednjiKomentar, PoslednjiTekst
                               FROM api_qa.AKTIVNOST_AUTORA ORDER BY BrojKomentara DESC, Autor;");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new AktivnostAutora
            {
                Autor = r.GetString(0), BrojKomentara = r.GetInt32(1),
                PoslednjiKomentar = Tekst(r, 2), PoslednjiTekst = Tekst(r, 3)
            });
        return lista;
    }

    // Isti izvestaj kao gore, samo kao XML dokument - to je ono sto FLWOR upit
    // u bazi zapravo proizvodi, a aplikacija ga samo snimi u fajl.
    public string IzvestajXml()
    {
        using var cmd = Procedura("api_qa.IzvestajAktivnostiXml");
        var rezultat = cmd.ExecuteScalar();
        return rezultat == DBNull.Value ? null : (string)rezultat;
    }

    public List<RezultatPretrage> Pretrazi(string upit, char rezim)
    {
        var lista = new List<RezultatPretrage>();
        using var cmd = Procedura("api_qa.PretraziGreske");
        cmd.Parameters.AddWithValue("@upit", upit);
        cmd.Parameters.AddWithValue("@rezim", rezim);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new RezultatPretrage
            {
                Id = r.GetInt32(0), NazivProjekta = r.GetString(1), Poruka = r.GetString(2),
                Ozbiljnost = r.GetInt32(3), Status = r.GetString(4),
                DatumPrijave = r.GetDateTime(5), Relevantnost = r.GetInt32(6)
            });
        return lista;
    }

    public List<PogodakTermina> NadjiPoTerminu(string termin)
    {
        var lista = new List<PogodakTermina>();
        using var cmd = Procedura("api_qa.NadjiPoTerminu");
        cmd.Parameters.AddWithValue("@termin", termin);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new PogodakTermina
            {
                GdePronadjeno = r.GetString(0), IdGreske = r.GetInt32(1), Projekat = r.GetString(2),
                Status = r.GetString(3), Autor = Tekst(r, 5),
                ElementXML = Tekst(r, 7), Sadrzaj = Tekst(r, 8)
            });
        return lista;
    }

    public List<GreskaNaSistemu> GreskePoSistemu(string obrazac)
    {
        var lista = new List<GreskaNaSistemu>();
        using var cmd = Upit(@"SELECT IdGreske, NazivProjekta, Poruka, StatusGr, Ozbiljnost,
                                      Autor, OperativniSistem, Pregledac
                               FROM api_qa.GRESKE_PO_SISTEMU(@obrazac) ORDER BY IdGreske;");
        cmd.Parameters.AddWithValue("@obrazac", obrazac);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new GreskaNaSistemu
            {
                IdGreske = r.GetInt32(0), NazivProjekta = r.GetString(1), Poruka = r.GetString(2),
                Status = r.GetString(3), Ozbiljnost = r.GetInt32(4), Autor = r.GetString(5),
                OperativniSistem = Tekst(r, 6), Pregledac = Tekst(r, 7)
            });
        return lista;
    }

    public List<PromenaStatusa> UcitajIstoriju()
    {
        var lista = new List<PromenaStatusa>();
        using var cmd = Upit(@"SELECT Id, IdGreske, NazivProjekta, StariStatus, NoviStatus,
                                      DatumPromene, Korisnik
                               FROM api_qa.ISTORIJA_STATUSA ORDER BY DatumPromene, Id;");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new PromenaStatusa
            {
                Id = r.GetInt32(0), IdGreske = r.GetInt32(1), NazivProjekta = Tekst(r, 2),
                StariStatus = Tekst(r, 3), NoviStatus = r.GetString(4),
                DatumPromene = r.GetDateTime(5), Korisnik = r.GetString(6)
            });
        return lista;
    }

    // Dijagnostika: proba nesto sto QA aplikacija NE SME i vraca sta je server
    // rekao. Sluzi da se u svakom trenutku moze pokazati da granica stvarno
    // postoji, a ne da samo pise u dokumentaciji.
    public List<(string Pokusaj, string Ishod)> ProveriGranice()
    {
        var probe = new (string Opis, string Sql)[]
        {
            ("SELECT из impl.tblGreska",      "SELECT TOP 1 Id FROM impl.tblGreska;"),
            ("SELECT из spec.vw_GRESKA",      "SELECT TOP 1 Id FROM spec.vw_GRESKA;"),
            ("SELECT из api_dev.GRESKE",      "SELECT TOP 1 Id FROM api_dev.GRESKE;"),
            ("INSERT у impl.tblProjekat",     "INSERT INTO impl.tblProjekat (Naziv,Opis,Verzija) VALUES (N'X',N'Y',N'1');"),
            ("SELECT из api_qa.GRESKE",       "SELECT TOP 1 Id FROM api_qa.GRESKE;")
        };

        var rezultat = new List<(string, string)>();
        foreach (var (opis, sql) in probe)
        {
            try
            {
                using var cmd = Upit(sql);
                cmd.ExecuteScalar();
                rezultat.Add((opis, "прошло"));
            }
            catch (SqlException ex)
            {
                rezultat.Add((opis, $"одбијено ({ex.Number})"));
            }
        }
        return rezultat;
    }

    public void Dispose() => _veza?.Dispose();
}
