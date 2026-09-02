using System;
using System.Data.SqlTypes;
using System.IO;
using System.Text;
using Microsoft.SqlServer.Server;

[Serializable]
[SqlUserDefinedAggregate(
    Format.UserDefined,

    IsInvariantToNulls      = true,
    IsInvariantToDuplicates = false,
    IsInvariantToOrder      = false,
    IsNullIfEmpty           = true,

    MaxByteSize             = -1,

    Name = "SpojPoruke")]
public struct SpojPoruke : IBinarySerialize
{
    private const string RAZDVAJAC = " | ";

    private StringBuilder bafer;

    private bool prazan;

    public void Init()
    {
        bafer = new StringBuilder();
        prazan = true;
    }

    public void Accumulate(SqlString poruka)
    {
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
            return SqlString.Null;

        return new SqlString(bafer.ToString());
    }

    public void Write(BinaryWriter pisac)
    {
        pisac.Write(prazan);
        pisac.Write(bafer == null ? string.Empty : bafer.ToString());
    }

    public void Read(BinaryReader citac)
    {
        prazan = citac.ReadBoolean();
        bafer  = new StringBuilder(citac.ReadString());
    }
}
