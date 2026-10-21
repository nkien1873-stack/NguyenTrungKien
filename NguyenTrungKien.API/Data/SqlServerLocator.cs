using Microsoft.Data.SqlClient;

namespace NguyenTrungKien.API.Data;

/// <summary>
/// Giúp máy nào cũng chạy được: thử chuỗi kết nối trong appsettings trước, không kết nối được thì
/// tự thử SQL Express (.\SQLEXPRESS) rồi LocalDB (có sẵn khi cài Visual Studio).
/// Database DB_NguyenTrungKien được EnsureCreated tự tạo trên server tìm được.
/// </summary>
public static class SqlServerLocator
{
    private static readonly string[] Fallbacks = [@".\SQLEXPRESS", @"(localdb)\MSSQLLocalDB"];

    public static string Resolve(string configured, bool autoDetect, out string message)
    {
        var builder = new SqlConnectionStringBuilder(configured);
        var servers = new List<string> { builder.DataSource };
        if (autoDetect) servers.AddRange(Fallbacks.Where(f => !f.Equals(builder.DataSource, StringComparison.OrdinalIgnoreCase)));

        foreach (var server in servers)
        {
            builder.DataSource = server;
            if (CanConnect(builder))
            {
                message = server == servers[0]
                    ? $"SQL Server: {server}"
                    : $"Không kết nối được '{servers[0]}' -> tự chuyển sang '{server}'";
                return builder.ConnectionString;
            }
        }

        message = $"Không kết nối được SQL Server nào ({string.Join(", ", servers)}). " +
                  "Cài SQL Server/SQL Express, hoặc sửa ConnectionStrings:DefaultConnection trong appsettings.json.";
        builder.DataSource = servers[0];
        return builder.ConnectionString;
    }

    /// <summary>Thử mở kết nối tới master (database của dự án có thể chưa được tạo).</summary>
    private static bool CanConnect(SqlConnectionStringBuilder target)
    {
        var probe = new SqlConnectionStringBuilder(target.ConnectionString)
        {
            InitialCatalog = "master",
            ConnectTimeout = target.DataSource.StartsWith("(localdb)", StringComparison.OrdinalIgnoreCase) ? 20 : 4
        };
        try
        {
            using var conn = new SqlConnection(probe.ConnectionString);
            conn.Open();
            return true;
        }
        catch (SqlException)
        {
            return false;
        }
        catch (InvalidOperationException)
        {
            return false;
        }
    }
}
