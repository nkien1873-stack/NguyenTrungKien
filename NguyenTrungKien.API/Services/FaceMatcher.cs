using System.Text.Json;

namespace NguyenTrungKien.API.Services;

/// <summary>
/// So khớp khuôn mặt dựa trên vector đặc trưng do app tính từ các điểm mốc (landmark) ML Kit.
/// Vector = khoảng cách giữa các điểm mốc đã chuẩn hóa theo khoảng cách hai mắt,
/// nên không phụ thuộc kích thước ảnh / khoảng cách tới camera.
/// Lưu ý: đây là mức demo cho đồ án; sản phẩm thật nên dùng embedding (FaceNet/ArcFace).
/// </summary>
public class FaceMatcher
{
    private readonly double _threshold;

    public FaceMatcher(IConfiguration config)
    {
        _threshold = config.GetValue<double?>("Face:Threshold") ?? 0.075;
    }

    public double Threshold => _threshold;

    /// <summary>Gộp nhiều mẫu lúc đăng ký thành 1 mẫu trung bình.</summary>
    public string BuildTemplate(List<double[]> samples)
    {
        var len = samples[0].Length;
        var avg = new double[len];
        foreach (var s in samples)
            for (var i = 0; i < len; i++) avg[i] += s[i] / samples.Count;
        return JsonSerializer.Serialize(avg);
    }

    /// <summary>Kiểm tra các mẫu lúc đăng ký có ổn định (cùng 1 người, không bị nhiễu) hay không.</summary>
    public bool SamplesConsistent(List<double[]> samples)
    {
        for (var i = 0; i < samples.Count; i++)
            for (var j = i + 1; j < samples.Count; j++)
                if (Distance(samples[i], samples[j]) > _threshold * 1.3) return false;
        return true;
    }

    public (bool match, double distance) Compare(string templateJson, double[] probe)
    {
        var template = JsonSerializer.Deserialize<double[]>(templateJson) ?? Array.Empty<double>();
        if (template.Length == 0 || template.Length != probe.Length) return (false, double.MaxValue);
        var d = Distance(template, probe);
        return (d <= _threshold, d);
    }

    /// <summary>RMS của chênh lệch từng thành phần.</summary>
    public static double Distance(double[] a, double[] b)
    {
        if (a.Length != b.Length || a.Length == 0) return double.MaxValue;
        double sum = 0;
        for (var i = 0; i < a.Length; i++) sum += (a[i] - b[i]) * (a[i] - b[i]);
        return Math.Sqrt(sum / a.Length);
    }
}

public static class Geo
{
    /// <summary>Khoảng cách Haversine (mét) giữa 2 tọa độ.</summary>
    public static double DistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        const double R = 6371000;
        double ToRad(double x) => x * Math.PI / 180;
        var dLat = ToRad(lat2 - lat1);
        var dLon = ToRad(lon2 - lon1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2)) * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return 2 * R * Math.Asin(Math.Sqrt(a));
    }
}
