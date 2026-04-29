import 'package:pdf/widgets.dart' as pw;

void main() {
  final chart = pw.Chart(
    grid: pw.CartesianGrid(
      xAxis: pw.FixedAxis([0, 1, 2]),
      yAxis: pw.FixedAxis([0, 10, 20]),
    ),
    datasets: [
      pw.LineDataSet(
        data: [
          pw.PointChartValue(0, 0),
          pw.PointChartValue(1, 10),
        ],
      )
    ]
  );
  print(chart);
}
