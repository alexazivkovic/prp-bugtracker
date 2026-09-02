using System.Text;
using ApplicationDEV.Podaci;
using ApplicationDEV.Ui;
using Microsoft.Data.SqlClient;

namespace ApplicationDEV;

public static class Program
{
    private static string Vezni()
    {
        var server = Environment.GetEnvironmentVariable("BT_SERVER") ?? "localhost,1433";
        var lozinka = Environment.GetEnvironmentVariable("BT_LOZINKA_DEV") ?? "Prp#Dev2026!";

        return $"Server={server};Database=BugTracker;User Id=AppLoginDEV;Password={lozinka};" +
               "Encrypt=True;TrustServerCertificate=True;Pooling=False;Connect Timeout=15;";
    }

    public static int Main()
    {
        Console.OutputEncoding = Encoding.UTF8;
        Console.InputEncoding = Encoding.UTF8;

        Console.WriteLine("BugTracker - апликација програмера");
        Console.WriteLine("Повезивање...");

        try
        {
            using var podaci = new DataProviderDEV(Vezni(), "Prp#RoleDev2026!");
            var identitet = podaci.Prijava();

            Ispis.Uspeh($"Повезан. Идентитет сесије: {identitet}");
            Console.WriteLine("(лево је логин, десно улога коју је sp_setapprole активирала)");

            var autor = Ispis.Pitaj("Ваше име (иде уз коментаре које будете уносили)");
            if (string.IsNullOrWhiteSpace(autor)) autor = "Програмер";

            new Meni(podaci, autor).Pokreni();
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
