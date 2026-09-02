namespace ApplicationQA.Model;

public class PregledProjekta
{
    public int Id { get; set; }
    public string Naziv { get; set; }
    public string Verzija { get; set; }
    public int UkupnoGresaka { get; set; }
    public int Nereseno { get; set; }
    public int Kriticnih { get; set; }
}

public class RedMatrice
{
    public int IdProjekta { get; set; }
    public string NazivProjekta { get; set; }
    public string Verzija { get; set; }
    public int Kriticnih { get; set; }
    public int Visokih { get; set; }
    public int Srednjih { get; set; }
    public int Niskih { get; set; }
    public int Informativnih { get; set; }
    public int Ukupno { get; set; }
}

public class OtvorenaGreska
{
    public int Id { get; set; }
    public string NazivProjekta { get; set; }
    public string Poruka { get; set; }
    public int Ozbiljnost { get; set; }
    public string OpisOzbiljnosti { get; set; }
    public DateTime DatumPrijave { get; set; }
    public string Status { get; set; }
    public int BrojKomentara { get; set; }
    public int DanaOtvorena { get; set; }
}

public class SazetakProjekta
{
    public int IdProjekta { get; set; }
    public string NazivProjekta { get; set; }
    public int BrojGresaka { get; set; }
    public string SvePoruke { get; set; }
}

public class AktivnostAutora
{
    public string Autor { get; set; }
    public int BrojKomentara { get; set; }
    public string PoslednjiKomentar { get; set; }
    public string PoslednjiTekst { get; set; }
}

public class RezultatPretrage
{
    public int Id { get; set; }
    public string NazivProjekta { get; set; }
    public string Poruka { get; set; }
    public int Ozbiljnost { get; set; }
    public string Status { get; set; }
    public DateTime DatumPrijave { get; set; }
    public int Relevantnost { get; set; }
}

public class PogodakTermina
{
    public string GdePronadjeno { get; set; }
    public int IdGreske { get; set; }
    public string Projekat { get; set; }
    public string Status { get; set; }
    public string Autor { get; set; }
    public string ElementXML { get; set; }
    public string Sadrzaj { get; set; }
}

public class GreskaNaSistemu
{
    public int IdGreske { get; set; }
    public string NazivProjekta { get; set; }
    public string Poruka { get; set; }
    public string Status { get; set; }
    public int Ozbiljnost { get; set; }
    public string Autor { get; set; }
    public string OperativniSistem { get; set; }
    public string Pregledac { get; set; }
}

public class PromenaStatusa
{
    public int Id { get; set; }
    public int IdGreske { get; set; }
    public string NazivProjekta { get; set; }
    public string StariStatus { get; set; }
    public string NoviStatus { get; set; }
    public DateTime DatumPromene { get; set; }
    public string Korisnik { get; set; }
}
