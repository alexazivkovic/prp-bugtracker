using System.Data;
using ApplicationDEV.Model;
using Microsoft.Data.SqlClient;

namespace ApplicationDEV.Podaci;

public sealed class DataProviderDEV : IDisposable
{
    private readonly SqlConnection _veza;
    private readonly string _lozinkaUloge;

    public DataProviderDEV(string vezniString, string lozinkaUloge)
    {
        _veza = new SqlConnection(vezniString);
        _lozinkaUloge = lozinkaUloge;
    }

    public string Prijava()
    {
        _veza.Open();

        using (var cmd = new SqlCommand("sp_setapprole", _veza) { CommandType = CommandType.StoredProcedure })
        {
            cmd.Parameters.AddWithValue("@rolename", "DataProviderDEV");
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
    private static int? Ceo(SqlDataReader r, int i) => r.IsDBNull(i) ? (int?)null : r.GetInt32(i);

    public List<string> UcitajStatuse()
    {
        var lista = new List<string>();
        using var cmd = Upit("SELECT StatusGr FROM api_dev.DOZVOLJENI_STATUSI() ORDER BY Redosled;");
        using var r = cmd.ExecuteReader();
        while (r.Read()) lista.Add(r.GetString(0));
        return lista;
    }

    public List<Projekat> UcitajProjekte()
    {
        var lista = new List<Projekat>();
        using var cmd = Upit(@"SELECT Id, NazivProjekta, Verzija, UkupnoGresaka, Nereseno, Kriticnih
                               FROM api_dev.PROJEKTI ORDER BY Id;");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new Projekat
            {
                Id = r.GetInt32(0), Naziv = r.GetString(1), Verzija = r.GetString(2),
                UkupnoGresaka = r.GetInt32(3), Nereseno = r.GetInt32(4), Kriticnih = r.GetInt32(5)
            });
        return lista;
    }

    public List<Greska> UcitajGreske(int? idProjekta)
    {
        var lista = new List<Greska>();
        using var cmd = Upit(@"SELECT Id, IdProjekta, NazivProjekta, VerzijaProjekta, Poruka,
                                      Ozbiljnost, OpisOzbiljnosti, DatumPrijave, StatusGr, BrojKomentara
                               FROM  api_dev.GRESKE
                               WHERE (@idProjekta IS NULL OR IdProjekta = @idProjekta)
                               ORDER BY Ozbiljnost, DatumPrijave;");
        cmd.Parameters.AddWithValue("@idProjekta", (object)idProjekta ?? DBNull.Value);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new Greska
            {
                Id = r.GetInt32(0), IdProjekta = r.GetInt32(1), NazivProjekta = r.GetString(2),
                VerzijaProjekta = r.GetString(3), Poruka = r.GetString(4), Ozbiljnost = r.GetInt32(5),
                OpisOzbiljnosti = r.GetString(6), DatumPrijave = r.GetDateTime(7),
                Status = r.GetString(8), BrojKomentara = r.GetInt32(9)
            });
        return lista;
    }

    public List<Greska> UcitajOtvorene()
    {
        var lista = new List<Greska>();
        using var cmd = Upit(@"SELECT Id, NazivProjekta, Poruka, Ozbiljnost, OpisOzbiljnosti,
                                      DatumPrijave, StatusGr, BrojKomentara, DanaOtvorena
                               FROM api_dev.OTVORENE_GRESKE ORDER BY Ozbiljnost, DatumPrijave;");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new Greska
            {
                Id = r.GetInt32(0), NazivProjekta = r.GetString(1), Poruka = r.GetString(2),
                Ozbiljnost = r.GetInt32(3), OpisOzbiljnosti = r.GetString(4),
                DatumPrijave = r.GetDateTime(5), Status = r.GetString(6),
                BrojKomentara = r.GetInt32(7), DanaOtvorena = r.GetInt32(8)
            });
        return lista;
    }

    public DetaljiGreske UcitajDetalje(int idGreske)
    {
        var d = new DetaljiGreske();
        using var cmd = Procedura("api_dev.DetaljiGreske");
        cmd.Parameters.AddWithValue("@idGreske", idGreske);
        using var r = cmd.ExecuteReader();

        if (r.Read())
            d.Zaglavlje = new Greska
            {
                Id = r.GetInt32(0), IdProjekta = r.GetInt32(1), NazivProjekta = r.GetString(2),
                VerzijaProjekta = r.GetString(3), Poruka = r.GetString(4), Ozbiljnost = r.GetInt32(5),
                OpisOzbiljnosti = r.GetString(6), DatumPrijave = r.GetDateTime(7),
                Status = r.GetString(8), BrojKomentara = r.GetInt32(9)
            };

        r.NextResult();
        while (r.Read())
            d.Komentari.Add(new Komentar
            {
                Id = r.GetInt32(0), Autor = r.GetString(1), DatumKom = r.GetDateTime(2),
                Tekst = Tekst(r, 3), Prioritet = Tekst(r, 4),
                OperativniSistem = Tekst(r, 5), Pregledac = Tekst(r, 6), BrojOznaka = r.GetInt32(7)
            });

        r.NextResult();
        while (r.Read())
            d.Oznake.Add(new Oznaka { IdKomentara = r.GetInt32(0), Autor = r.GetString(1), Naziv = Tekst(r, 2) });

        r.NextResult();
        while (r.Read())
            d.Okruzenja.Add(new Okruzenje
            {
                IdKomentara = r.GetInt32(0), Autor = r.GetString(1), DatumKom = r.GetDateTime(2),
                OperativniSistem = Tekst(r, 3), Pregledac = Tekst(r, 4)
            });

        r.NextResult();
        while (r.Read())
            d.Istorija.Add(new PromenaStatusa
            {
                Id = r.GetInt32(0), StariStatus = Tekst(r, 1), NoviStatus = r.GetString(2),
                DatumPromene = r.GetDateTime(3), Korisnik = r.GetString(4)
            });

        return d;
    }

    public int PrijaviGresku(int idProjekta, string poruka, int ozbiljnost, DateTime? datum, string status)
    {
        using var cmd = Procedura("api_dev.PrijaviGresku");
        cmd.Parameters.AddWithValue("@idProjekta", idProjekta);
        cmd.Parameters.AddWithValue("@poruka", poruka);
        cmd.Parameters.AddWithValue("@ozbiljnost", ozbiljnost);
        cmd.Parameters.AddWithValue("@datumPrijave", (object)datum ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@statusGr", status);

        var izlaz = new SqlParameter("@idGreske", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(izlaz);

        cmd.ExecuteNonQuery();
        return (int)izlaz.Value;
    }

    public int DodajKomentar(int idGreske, string autor, string tekst, string prioritet,
                             string os, string pregledac, string oznake, string resenje)
    {
        using var cmd = Procedura("api_dev.DodajKomentar");
        cmd.Parameters.AddWithValue("@idGreske", idGreske);
        cmd.Parameters.AddWithValue("@autor", autor);
        cmd.Parameters.AddWithValue("@tekst", tekst);
        cmd.Parameters.AddWithValue("@prioritet", Prazno(prioritet));
        cmd.Parameters.AddWithValue("@os", Prazno(os));
        cmd.Parameters.AddWithValue("@pregledac", Prazno(pregledac));
        cmd.Parameters.AddWithValue("@oznake", Prazno(oznake));
        cmd.Parameters.AddWithValue("@resenje", Prazno(resenje));

        var izlaz = new SqlParameter("@idKomentar", SqlDbType.Int) { Direction = ParameterDirection.Output };
        cmd.Parameters.Add(izlaz);

        cmd.ExecuteNonQuery();
        return (int)izlaz.Value;
    }

    private static object Prazno(string s) => string.IsNullOrWhiteSpace(s) ? DBNull.Value : (object)s.Trim();

    public void PromeniStatus(int idGreske, string noviStatus)
    {
        using var cmd = Procedura("api_dev.PromeniStatus");
        cmd.Parameters.AddWithValue("@idGreske", idGreske);
        cmd.Parameters.AddWithValue("@noviStatus", noviStatus);
        cmd.ExecuteNonQuery();
    }

    public List<RezultatPretrage> Pretrazi(string upit, char rezim)
    {
        var lista = new List<RezultatPretrage>();
        using var cmd = Procedura("api_dev.PretraziGreske");
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
        using var cmd = Procedura("api_dev.NadjiPoTerminu");
        cmd.Parameters.AddWithValue("@termin", termin);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new PogodakTermina
            {
                GdePronadjeno = r.GetString(0), IdGreske = r.GetInt32(1), Projekat = r.GetString(2),
                Status = r.GetString(3), IdKomentara = Ceo(r, 4), Autor = Tekst(r, 5),
                ElementXML = Tekst(r, 7), Sadrzaj = Tekst(r, 8)
            });
        return lista;
    }

    public List<AktivnostAutora> UcitajAktivnost()
    {
        var lista = new List<AktivnostAutora>();
        using var cmd = Upit(@"SELECT Autor, BrojKomentara, PoslednjiKomentar, PoslednjiTekst
                               FROM api_dev.AKTIVNOST_AUTORA ORDER BY BrojKomentara DESC, Autor;");
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new AktivnostAutora
            {
                Autor = r.GetString(0), BrojKomentara = r.GetInt32(1),
                PoslednjiKomentar = Tekst(r, 2), PoslednjiTekst = Tekst(r, 3)
            });
        return lista;
    }

    public List<RedMatrice> UcitajMatricu(int? idProjekta)
    {
        var lista = new List<RedMatrice>();
        using var cmd = Procedura("api_dev.MatricaGresaka");
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

    public List<PromenaStatusa> UcitajIstoriju(int? idGreske)
    {
        var lista = new List<PromenaStatusa>();
        using var cmd = Upit(@"SELECT Id, IdGreske, StariStatus, NoviStatus, DatumPromene, Korisnik
                               FROM  api_dev.ISTORIJA_STATUSA
                               WHERE (@idGreske IS NULL OR IdGreske = @idGreske)
                               ORDER BY DatumPromene, Id;");
        cmd.Parameters.AddWithValue("@idGreske", (object)idGreske ?? DBNull.Value);
        using var r = cmd.ExecuteReader();
        while (r.Read())
            lista.Add(new PromenaStatusa
            {
                Id = r.GetInt32(0), IdGreske = r.GetInt32(1), StariStatus = Tekst(r, 2),
                NoviStatus = r.GetString(3), DatumPromene = r.GetDateTime(4), Korisnik = r.GetString(5)
            });
        return lista;
    }

    public void Dispose() => _veza?.Dispose();
}
