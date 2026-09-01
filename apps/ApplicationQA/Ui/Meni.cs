using ApplicationQA.Podaci;
using Microsoft.Data.SqlClient;

namespace ApplicationQA.Ui;

// Prezentacioni sloj QA aplikacije. Sve stavke su izvestajne - nigde se nista
// ne unosi ni menja, jer ni sema api_qa to ne dozvoljava.
public class Meni
{
    private readonly DataProviderQA _podaci;

    public Meni(DataProviderQA podaci) => _podaci = podaci;

    public void Pokreni()
    {
        while (true)
        {
            Prikazi();
            var izbor = Ispis.Pitaj("Izbor");
            if (izbor == "0") return;

            try
            {
                switch (izbor)
                {
                    case "1":  Projekti();     break;
                    case "2":  Matrica();      break;
                    case "3":  Otvorene();     break;
                    case "4":  Sazetak();      break;
                    case "5":  Aktivnost();    break;
                    case "6":  IzvozXml();     break;
                    case "7":  Pretraga();     break;
                    case "8":  PoTerminu();    break;
                    case "9":  PoSistemu();    break;
                    case "10": Istorija();     break;
                    case "11": Granice();      break;
                    default:   Ispis.Greska("Nepoznata stavka."); break;
                }
            }
            catch (SqlException ex)
            {
                // 50000 navise su nase poruke iz procedura, ispod toga je
                // tehnicka greska servera
                if (ex.Number >= 50000) Ispis.Greska($"Одбијено: {ex.Message}");
                else                    Ispis.Greska($"Greska baze ({ex.Number}): {ex.Message}");
            }

            Ispis.Pauza();
        }
    }

    private void Prikazi()
    {
        Console.WriteLine();
        Console.WriteLine("=== BugTracker - апликација за контролу квалитета (QA) ===");
        Console.WriteLine(" 1. Преглед пројеката");
        Console.WriteLine(" 2. Матрица грешака по озбиљности");
        Console.WriteLine(" 3. Отворене грешке");
        Console.WriteLine(" 4. Сажетак порука по пројекту");
        Console.WriteLine(" 5. Активност аутора");
        Console.WriteLine(" 6. Извези извештај у XML фајл");
        Console.WriteLine(" 7. Претрага");
        Console.WriteLine(" 8. Нађи по термину");
        Console.WriteLine(" 9. Грешке по оперативном систему");
        Console.WriteLine("10. Историја статуса");
        Console.WriteLine("11. Провера граница приступа");
        Console.WriteLine(" 0. Излаз");
    }

    private void Projekti()
    {
        Ispis.Naslov("Преглед пројеката");
        Ispis.Tabela(new[] { "Ид", "Пројекат", "Верзија", "Грешака", "Нерешено", "Критичних" },
            _podaci.UcitajProjekte().Select(p => new[] { p.Id.ToString(), p.Naziv, p.Verzija,
                p.UkupnoGresaka.ToString(), p.Nereseno.ToString(), p.Kriticnih.ToString() }).ToList());
    }

    private void Matrica()
    {
        var id = Ispis.PitajBroj("Ид пројекта (Enter = сви)");
        Ispis.Naslov("Матрица грешака");
        Ispis.Tabela(new[] { "Ид", "Пројекат", "Критичних", "Високих", "Средњих", "Ниских", "Инфо", "Укупно" },
            _podaci.UcitajMatricu(id).Select(m => new[] { m.IdProjekta.ToString(), m.NazivProjekta,
                m.Kriticnih.ToString(), m.Visokih.ToString(), m.Srednjih.ToString(),
                m.Niskih.ToString(), m.Informativnih.ToString(), m.Ukupno.ToString() }).ToList());
    }

    private void Otvorene()
    {
        Ispis.Naslov("Отворене грешке - најстарије прво");
        Ispis.Tabela(new[] { "Ид", "Пројекат", "Озбиљност", "Статус", "Дана", "Ком.", "Порука" },
            _podaci.UcitajOtvorene().Select(g => new[] { g.Id.ToString(), g.NazivProjekta,
                g.OpisOzbiljnosti, g.Status, g.DanaOtvorena.ToString(),
                g.BrojKomentara.ToString(), g.Poruka }).ToList());
    }

    private void Sazetak()
    {
        Ispis.Naslov("Сажетак порука по пројекту");
        Console.WriteLine("(поруке спаја CLR агрегатна функција impl.SpojPoruke)");
        foreach (var s in _podaci.UcitajSazetak())
        {
            Console.WriteLine();
            Console.WriteLine($"{s.IdProjekta}. {s.NazivProjekta}  -  {s.BrojGresaka} грешака");
            Console.WriteLine("   " + (s.SvePoruke ?? "(нема пријављених грешака)"));
        }
    }

    private void Aktivnost()
    {
        Ispis.Naslov("Активност аутора");
        Ispis.Tabela(new[] { "Аутор", "Коментара", "Последњи", "Текст" },
            _podaci.UcitajAktivnost().Select(a => new[] { a.Autor, a.BrojKomentara.ToString(),
                a.PoslednjiKomentar, a.PoslednjiTekst }).ToList());
    }

    private void IzvozXml()
    {
        Ispis.Naslov("Извоз извештаја");
        var xml = _podaci.IzvestajXml();
        if (string.IsNullOrWhiteSpace(xml)) { Ispis.Greska("Извештај је празан."); return; }

        var putanja = Path.Combine(Directory.GetCurrentDirectory(),
                                   $"izvestaj_aktivnosti_{DateTime.Now:yyyyMMdd_HHmm}.xml");
        File.WriteAllText(putanja, xml, System.Text.Encoding.UTF8);
        Ispis.Uspeh($"Снимљено: {putanja}");
        Console.WriteLine();
        Console.WriteLine(xml.Length > 500 ? xml.Substring(0, 500) + "..." : xml);
    }

    private void Pretraga()
    {
        Ispis.Naslov("Претрага грешака");
        Console.WriteLine("Режим N (напредна): AND, OR, AND NOT, NEAR, звездица на крају речи.");
        Console.WriteLine("Режим S (слободна): обична реченица.");
        var rezim = Ispis.Pitaj("Режим (N/S)").ToUpperInvariant() == "S" ? 'F' : 'C';
        var upit = Ispis.Pitaj("Услов претраге");

        Ispis.Tabela(new[] { "Ид", "Пројекат", "Релевантност", "Статус", "Порука" },
            _podaci.Pretrazi(upit, rezim).Select(r => new[] { r.Id.ToString(), r.NazivProjekta,
                r.Relevantnost.ToString(), r.Status, r.Poruka }).ToList());
    }

    private void PoTerminu()
    {
        Ispis.Naslov("Претрага по термину кроз коментаре");
        var termin = Ispis.Pitaj("Термин");
        Ispis.Tabela(new[] { "Где", "Грешка", "Пројекат", "Аутор", "Елемент", "Садржај" },
            _podaci.NadjiPoTerminu(termin).Select(p => new[] { p.GdePronadjeno, p.IdGreske.ToString(),
                p.Projekat, p.Autor ?? "-", p.ElementXML, p.Sadrzaj }).ToList());
    }

    private void PoSistemu()
    {
        Ispis.Naslov("Грешке по оперативном систему");
        var obrazac = Ispis.Pitaj("Део назива ОС-а (нпр. Android, Windows, macOS)");
        Ispis.Tabela(new[] { "Грешка", "Пројекат", "ОС", "Прегледач", "Аутор", "Статус", "Порука" },
            _podaci.GreskePoSistemu(obrazac).Select(g => new[] { g.IdGreske.ToString(), g.NazivProjekta,
                g.OperativniSistem ?? "-", g.Pregledac ?? "-", g.Autor, g.Status, g.Poruka }).ToList());
    }

    private void Istorija()
    {
        Ispis.Naslov("Историја промена статуса");
        Ispis.Tabela(new[] { "Ид", "Грешка", "Пројекат", "Из", "У", "Када", "Ко" },
            _podaci.UcitajIstoriju().Select(h => new[] { h.Id.ToString(), h.IdGreske.ToString(),
                h.NazivProjekta ?? "-", h.StariStatus ?? "-", h.NoviStatus,
                h.DatumPromene.ToString("yyyy-MM-dd HH:mm"), h.Korisnik }).ToList());
    }

    private void Granice()
    {
        Ispis.Naslov("Провера граница приступа");
        Console.WriteLine("Апликација покушава оно што сме и оно што не сме, па пријављује шта је сервер рекао.");
        Ispis.Tabela(new[] { "Покушај", "Исход" },
            _podaci.ProveriGranice().Select(p => new[] { p.Pokusaj, p.Ishod }).ToList());
    }
}
