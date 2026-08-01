param(
  [string]$Source = "$PSScriptRoot\..\design\source-assets\runtime-originals\assets\brand\morrowloom-icon-source.png",
  [string]$Output = "$PSScriptRoot\..\design\source-assets\runtime-originals\assets\brand\morrowloom-tapestry-room.png"
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies 'System.Drawing.dll' -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class TapestryCutout {
    private static double SmoothStep(double value) {
        value = Math.Max(0.0, Math.Min(1.0, value));
        return value * value * (3.0 - 2.0 * value);
    }

    public static void Build(string sourcePath, string outputPath) {
        using (var source = new Bitmap(sourcePath))
        using (var result = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb)) {
            using (var graphics = Graphics.FromImage(result)) {
                graphics.DrawImageUnscaled(source, 0, 0);
            }

            var rect = new Rectangle(0, 0, result.Width, result.Height);
            var data = result.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            var bytes = new byte[Math.Abs(data.Stride) * data.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);

            var ropeCenters = new[] { 261, 351, 444, 546, 634, 725, 817, 911, 1026 };
            for (var y = 0; y < result.Height; y++) {
                double rowR = 0, rowG = 0, rowB = 0;
                const int edge = 36;
                for (var x = 0; x < edge; x++) {
                    var left = y * data.Stride + x * 4;
                    var right = y * data.Stride + (result.Width - 1 - x) * 4;
                    rowB += bytes[left] + bytes[right];
                    rowG += bytes[left + 1] + bytes[right + 1];
                    rowR += bytes[left + 2] + bytes[right + 2];
                }
                rowR /= edge * 2.0;
                rowG /= edge * 2.0;
                rowB /= edge * 2.0;

                for (var x = 0; x < result.Width; x++) {
                    var offset = y * data.Stride + x * 4;
                    var b = bytes[offset];
                    var g = bytes[offset + 1];
                    var r = bytes[offset + 2];
                    var dr = r - rowR;
                    var dg = g - rowG;
                    var db = b - rowB;
                    var distance = Math.Sqrt(dr * dr + dg * dg + db * db);
                    var alpha = (byte)Math.Round(255.0 * SmoothStep((distance - 8.0) / 34.0));

                    // The textile body contains deliberately near-black woven
                    // rows that resemble the backdrop in colour. Keep that
                    // connected cloth opaque while the outer surround clears.
                    var protectedBody = x >= 195 && x <= 1085 && y >= 205 && y <= 900;
                    var protectedRope = false;
                    if (y >= 920) {
                        foreach (var center in ropeCenters) {
                            if (Math.Abs(x - center) <= 4) {
                                protectedRope = true;
                                break;
                            }
                        }
                    }
                    if (protectedBody || protectedRope) alpha = 255;
                    bytes[offset + 3] = alpha;
                }
            }

            Marshal.Copy(bytes, 0, data.Scan0, bytes.Length);
            result.UnlockBits(data);
            const int roomSize = 640;
            using (var scaled = new Bitmap(roomSize, roomSize, PixelFormat.Format32bppArgb))
            using (var graphics = Graphics.FromImage(scaled)) {
                graphics.Clear(Color.Transparent);
                graphics.CompositingMode = CompositingMode.SourceCopy;
                graphics.CompositingQuality = CompositingQuality.HighQuality;
                graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                graphics.SmoothingMode = SmoothingMode.HighQuality;
                graphics.DrawImage(result, new Rectangle(0, 0, roomSize, roomSize));
                scaled.Save(outputPath, ImageFormat.Png);
            }
        }
    }
}
'@

$sourcePath = [System.IO.Path]::GetFullPath($Source)
$outputPath = [System.IO.Path]::GetFullPath($Output)
[TapestryCutout]::Build($sourcePath, $outputPath)
Write-Output $outputPath
