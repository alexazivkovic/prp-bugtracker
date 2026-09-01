using ApplicationDEV.Model;
using ApplicationDEV.Podaci;
using Microsoft.Data.SqlClient;

namespace ApplicationDEV.Ui;

// Prezentacioni sloj. Zna za domenske klase i za DataProviderDEV, ali ne zna
// nista o SQL-u - nijedan upit se ne pise ovde. Kad bi se sutra baza zamenila
// necim drugim, menjao bi se samo sloj ispod.
public class Meni
{
    private readonly DataProviderDEV _podaci;
    private readonly string _autor;   // ko je prijavljen, ide u komentare

    public Meni(DataProviderDEV podaci, string autor)
    {
        _podaci = podaci;
        _autor = autor;
    }

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
                    case "1":  Projekti();        break;
                    case "2":  Greske();          break;
                    case "3":  Otvorene();        break;
                    case "4":  Detalji();         break;
                    case "5":  PrijavaGreske();   break;
                    case "6":  NoviKomentar();    break;
                    case "7":  PromenaStatusa();  break;
                    case "8":  Pretraga();        break;
                    case "9":  PoTerminu();       break;
                    case "10": Aktivnost();       break;
                    case "11": Matrica();         break;
                    case "12": Istorija();        break;
                    default:   Ispis.Greska("Nepoznata stavka."); break;
                }
            }
            catch (SqlException ex)
            {
                // Brojevi od 50000 navise su NASI izuzeci iz procedura, sa
                // porukom prepisanom iz tabela SPI i VPI dokumentacije - njih
                // korisniku prikazujemo kakve jesu. Sve ispod toga je tehnicka
                // greska servera i nju samo prijavljujemo.
                if (ex.Number >= 50000)
                    Ispis.Greska($"Одбијено: {ex.Message}");
                else
                    Ispis.Greska($"Greska baze ({ex.Number}): {ex.Message}");
            }

            Ispis.Pauza();
        }
    }

    private void Prikazi()
    {
        Console.WriteLine();
        Console.WriteLine("=== BugTracker - апликација програмера (DEV) ===");
        Console.WriteLine(" 1. Пројекти");
        Console.WriteLine(" 2. Грешке");
        Console.WriteLine(" 3. Отворене грешке");
        Console.WriteLine(" 4. Детаљи грешке");
        Console.WriteLine(" 5. Пријави грешку");
        Console.WriteLine(" 6. Додај коментар");
        Console.WriteLine(" 7. Промени статус");
        Console.WriteLine(" 8. Претрага");
        Console.WriteLine(" 9. Нађи по термину");
        Console.WriteLine("10. Активност аутора");
        Console.WriteLine("11. Матрица грешака");
        Console.WriteLine("12. Историја статуса");
        Console.WriteLine(" 0. Излаз");
    }

    private void Projekti()
    {
        Ispis.Naslov("Пројекти");
        var lista = _podaci.UcitajProjekte();
        Ispis.Tabela(
            new[] { "Ид", "Назив", "Верзија", "Грешака", "Нерешено", "Критичних" },
            lista.Select(p => new[] { p.Id.ToString(), p.Naziv, p.Verzija,
                                      p.UkupnoGresaka.ToString(), p.Nereseno.ToString(), p.Kriticnih.ToString() }).ToList());
    }

    private void Greske()
    {
        var id = Ispis.PitajBroj("Ид пројекта (Enter = све)");
        Ispis.Naslov(id.HasValue ? $"Грешке пројекта {id}" : "Све грешке");
        var lista = _podaci.UcitajGreske(id);
        Ispis.Tabela(
            new[] { "Ид", "Пројекат", "Озбиљност", "Статус", "Пријављена", "Ком.", "Порука" },
            lista.Select(g => new[] { g.Id.ToString(), g.NazivProjekta, g.OpisOzbiljnosti, g.Status,
                                      g.DatumPrijave.ToString("yyyy-MM-dd"), g.BrojKomentara.ToString(), g.Poruka }).ToList());
    }

    private void Otvorene()
    {
        Ispis.Naslov("Отворене грешке");
        var lista = _podaci.UcitajOtvorene();
        Ispis.Tabela(
            new[] { "Ид", "Пројекат", "Озбиљност", "Статус", "Дана", "Порука" },
            lista.Select(g => new[] { g.Id.ToString(), g.NazivProjekta, g.OpisOzbiljnosti, g.Status,
                                      g.DanaOtvorena.ToString(), g.Poruka }).ToList());
    }

    private void Detalji()
    {
        var id = Ispis.PitajBroj("Ид грешке");
        if (id is null) { Ispis.Greska("Морате унети број."); return; }

        var d = _podaci.UcitajDetalje(id.Value);
        var g = d.Zaglavlje;

        Ispis.Naslov($"Грешка {g.Id} - {g.NazivProjekta} {g.VerzijaProjekta}");
        Console.WriteLine(g.Poruka);
        Console.WriteLine($"Озбиљност: {g.OpisOzbiljnosti} ({g.Ozbiljnost})   Статус: {g.Status}   Пријављена: {g.DatumPrijave:yyyy-MM-dd}");

        Ispis.Naslov("Коментари");
        Ispis.Tabela(new[] { "Ид", "Аутор", "Датум", "Приоритет", "Текст" },
            d.Komentari.Select(k => new[] { k.Id.ToString(), k.Autor, k.DatumKom.ToString("yyyy-MM-dd HH:mm"),
                                            k.Prioritet ?? "-", k.Tekst }).ToList());

        Ispis.Naslov("Ознаке");
        Ispis.Tabela(new[] { "Коментар", "Аутор", "Ознака" },
            d.Oznake.Select(o => new[] { o.IdKomentara.ToString(), o.Autor, o.Naziv }).ToList());

        Ispis.Naslov("Окружења у којима је пријављена");
        Ispis.Tabela(new[] { "Коментар", "Аутор", "ОС", "Прегледач" },
            d.Okruzenja.Select(o => new[] { o.IdKomentara.ToString(), o.Autor,
                                            o.OperativniSistem ?? "-", o.Pregledac ?? "-" }).ToList());

        Ispis.Naslov("Историја статуса");
        Ispis.Tabela(new[] { "Из", "У", "Када", "Ко" },
            d.Istorija.Select(h => new[] { h.StariStatus ?? "-", h.NoviStatus,
                                           h.DatumPromene.ToString("yyyy-MM-dd HH:mm"), h.Korisnik }).ToList());
    }

    private void PrijavaGreske()
    {
        Ispis.Naslov("Пријава нове грешке");
        Projekti();

        var idProjekta = Ispis.PitajBroj("Ид пројекта");
        if (idProjekta is null) { Ispis.Greska("Морате унети број."); return; }

        var poruka = Ispis.Pitaj("Опис грешке");
        var ozbiljnost = Ispis.PitajBroj("Озбиљност 1-5 (1 = критична)");
        if (ozbiljnost is null) { Ispis.Greska("Морате унети број."); return; }

        // datum se ne pita - baza sama stavlja danasnji ako posaljemo NULL
        var noviId = _podaci.PrijaviGresku(idProjekta.Value, poruka, ozbiljnost.Value, null, "Отворена");
        Ispis.Uspeh($"Грешка је пријављена, добила је Ид {noviId}.");
    }

    private void NoviKomentar()
    {
        Ispis.Naslov("Нови коментар");
        var idGreske = Ispis.PitajBroj("Ид грешке");
        if (idGreske is null) { Ispis.Greska("Морате унети број."); return; }

        var tekst     = Ispis.Pitaj("Текст коментара");
        var prioritet = Ispis.Pitaj("Приоритет (Enter = прескочи)");
        var os        = Ispis.Pitaj("Оперативни систем (Enter = прескочи)");
        var pregledac = Ispis.Pitaj("Прегледач (Enter = прескочи)");
        var oznake    = Ispis.Pitaj("Ознаке, раздвојене зарезом (Enter = прескочи)");
        var resenje   = Ispis.Pitaj("Решење - ако се попуни, грешка се аутоматски затвара (Enter = прескочи)");

        var noviId = _podaci.DodajKomentar(idGreske.Value, _autor, tekst, prioritet, os, pregledac, oznake, resenje);
        Ispis.Uspeh($"Коментар је додат, Ид {noviId}.");

        if (!string.IsNullOrWhiteSpace(resenje))
            Ispis.Uspeh("Пошто је решење попуњено, тригер у бази је грешку пребацио у статус „Решена“.");
    }

    private void PromenaStatusa()
    {
        Ispis.Naslov("Промена статуса");
        var idGreske = Ispis.PitajBroj("Ид грешке");
        if (idGreske is null) { Ispis.Greska("Морате унети број."); return; }

        // listu statusa vuce iz baze, ne drzi je prekucanu u aplikaciji
        var statusi = _podaci.UcitajStatuse();
        for (int i = 0; i < statusi.Count; i++) Console.WriteLine($"  {i + 1}. {statusi[i]}");

        var izbor = Ispis.PitajBroj("Нови статус (редни број)");
        if (izbor is null || izbor < 1 || izbor > statusi.Count) { Ispis.Greska("Погрешан избор."); return; }

        _podaci.PromeniStatus(idGreske.Value, statusi[izbor.Value - 1]);
        Ispis.Uspeh("Статус је промењен, промена је уписана у историју.");
    }

    private void Pretraga()
    {
        Ispis.Naslov("Претрага грешака");
        Console.WriteLine("Режим N (напредна): смеју оператори AND, OR, AND NOT, NEAR и звездица на крају речи.");
        Console.WriteLine("   примери:  лозинке OR GPS      \"учита*\" AND NOT Safari      NEAR((Апликација, руши), 3, FALSE)");
        Console.WriteLine("Режим S (слободна): обична реченица, без оператора.");

        var rezim = Ispis.Pitaj("Режим (N/S)").ToUpperInvariant() == "S" ? 'F' : 'C';
        var upit  = Ispis.Pitaj("Услов претраге");

        var lista = _podaci.Pretrazi(upit, rezim);
        Ispis.Tabela(new[] { "Ид", "Пројекат", "Релевантност", "Статус", "Порука" },
            lista.Select(r => new[] { r.Id.ToString(), r.NazivProjekta, r.Relevantnost.ToString(),
                                      r.Status, r.Poruka }).ToList());
    }

    private void PoTerminu()
    {
        Ispis.Naslov("Претрага по термину кроз коментаре");
        var termin = Ispis.Pitaj("Термин");
        var lista = _podaci.NadjiPoTerminu(termin);
        Ispis.Tabela(new[] { "Где", "Грешка", "Пројекат", "Аутор", "Елемент", "Садржај" },
            lista.Select(p => new[] { p.GdePronadjeno, p.IdGreske.ToString(), p.Projekat,
                                      p.Autor ?? "-", p.ElementXML, p.Sadrzaj }).ToList());
    }

    private void Aktivnost()
    {
        Ispis.Naslov("Активност аутора");
        var lista = _podaci.UcitajAktivnost();
        Ispis.Tabela(new[] { "Аутор", "Коментара", "Последњи", "Текст" },
            lista.Select(a => new[] { a.Autor, a.BrojKomentara.ToString(),
                                      a.PoslednjiKomentar, a.PoslednjiTekst }).ToList());
    }

    private void Matrica()
    {
        Ispis.Naslov("Матрица грешака по озбиљности");
        var lista = _podaci.UcitajMatricu(null);
        Ispis.Tabela(new[] { "Ид", "Пројекат", "Критичних", "Високих", "Средњих", "Ниских", "Инфо", "Укупно" },
            lista.Select(m => new[] { m.IdProjekta.ToString(), m.NazivProjekta, m.Kriticnih.ToString(),
                                      m.Visokih.ToString(), m.Srednjih.ToString(), m.Niskih.ToString(),
                                      m.Informativnih.ToString(), m.Ukupno.ToString() }).ToList());
    }

    private void Istorija()
    {
        var id = Ispis.PitajBroj("Ид грешке (Enter = све)");
        Ispis.Naslov("Историја промена статуса");
        var lista = _podaci.UcitajIstoriju(id);
        Ispis.Tabela(new[] { "Ид", "Грешка", "Из", "У", "Када", "Ко" },
            lista.Select(h => new[] { h.Id.ToString(), h.IdGreske.ToString(), h.StariStatus ?? "-",
                                      h.NoviStatus, h.DatumPromene.ToString("yyyy-MM-dd HH:mm"), h.Korisnik }).ToList());
    }
}
