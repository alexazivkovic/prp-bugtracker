using System.Text;
using ApplicationQA.Podaci;
using ApplicationQA.Ui;
using Microsoft.Data.SqlClient;

namespace ApplicationQA;

// Ulazna tacka QA aplikacije. Ista uloga kao u DEV aplikaciji - sastavlja
// slojeve i pusta meni.
public static class Program
{
    private static string Vezni()
    {
        var server = Environment.GetEnvironmentVariable("BT_SERVER") ?? "localhost,1433";
        var lozinka = Environment.GetEnvironmentVariable("BT_LOZINKA_QA") ?? "Prp#Qa2026!";
        return $"Server={server};Database=BugTracker;User Id=AppLoginQA;Password={lozinka};" +
               "Encrypt=True;TrustServerCertificate=True;Pooling=False;Connect Timeout=15;";
    }

    public static int Main()
    {
        Console.OutputEncoding = Encoding.UTF8;
        Console.InputEncoding = Encoding.UTF8;

        Console.WriteLine("BugTracker - апликација за контролу квалитета");
        Console.WriteLine("Повезивање...");

        try
        {
            using var podaci = new DataProviderQA(Vezni(), "Prp#RoleQa2026!");
            var identitet = podaci.Prijava();

            Ispis.Uspeh($"Повезан. Идентитет сесије: {identitet}");
            new Meni(podaci).Pokreni();
            Console.WriteLine("Довиђења.");
            return 0;
        }
        catch (SqlException ex)
        {
            Ispis.Greska($"Не могу да се повежем на базу: {ex.Message}");
            Console.WriteLine("Провери да ли контејнер ради:  ./scripts/db-up.sh");
            return 1;
        }
    }
}
