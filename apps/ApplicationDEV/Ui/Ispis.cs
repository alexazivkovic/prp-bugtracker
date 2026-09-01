namespace ApplicationDEV.Ui;

// Sitni pomocnici za konzolu - crtanje tabele, pitanja korisniku, poruke.
// Ovde nema nikakve poslovne logike ni pristupa bazi, samo ulaz i izlaz.
public static class Ispis
{
    public static void Naslov(string tekst)
    {
        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.WriteLine(tekst);
        Console.WriteLine(new string('-', tekst.Length));
        Console.ResetColor();
    }

    public static void Uspeh(string tekst)
    {
        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine(tekst);
        Console.ResetColor();
    }

    public static void Greska(string tekst)
    {
        Console.ForegroundColor = ConsoleColor.Red;
        Console.WriteLine(tekst);
        Console.ResetColor();
    }

    // Racuna sirinu svake kolone prema najduzoj vrednosti, pa poravna.
    // Duge tekstove sece da red ne bi prelazio u drugi.
    public static void Tabela(string[] zaglavlja, List<string[]> redovi, int maxSirina = 46)
    {
        if (redovi.Count == 0) { Console.WriteLine("(nema podataka)"); return; }

        var sirine = new int[zaglavlja.Length];
        for (int i = 0; i < zaglavlja.Length; i++)
        {
            sirine[i] = zaglavlja[i].Length;
            foreach (var red in redovi)
            {
                var v = red[i] ?? "";
                if (v.Length > sirine[i]) sirine[i] = v.Length;
            }
            if (sirine[i] > maxSirina) sirine[i] = maxSirina;
        }

        Console.WriteLine(string.Join("  ", zaglavlja.Select((z, i) => z.PadRight(sirine[i]))));
        Console.WriteLine(string.Join("  ", sirine.Select(s => new string('-', s))));

        foreach (var red in redovi)
            Console.WriteLine(string.Join("  ", red.Select((v, i) => Skrati(v, sirine[i]).PadRight(sirine[i]))));

        Console.WriteLine($"({redovi.Count} redova)");
    }

    private static string Skrati(string v, int n)
    {
        v ??= "";
        return v.Length <= n ? v : v.Substring(0, Math.Max(0, n - 1)) + "...";
    }

    public static string Pitaj(string pitanje)
    {
        Console.Write(pitanje + ": ");
        return Console.ReadLine()?.Trim() ?? "";
    }

    // vraca null ako korisnik samo pritisne Enter, za neobavezna polja
    public static int? PitajBroj(string pitanje)
    {
        var s = Pitaj(pitanje);
        if (string.IsNullOrWhiteSpace(s)) return null;
        return int.TryParse(s, out var n) ? n : (int?)null;
    }

    public static void Pauza()
    {
        Console.WriteLine();
        Console.Write("Enter za nastavak...");
        Console.ReadLine();
    }
}
