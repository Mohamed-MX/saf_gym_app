import 'dart:convert';
import 'dart:io';

class MuscleWikiExercise {
  final int id;
  final String name;
  final String? thumbnailUrl;

  MuscleWikiExercise({required this.id, required this.name, this.thumbnailUrl});

  static MuscleWikiExercise mapper(Map<String, dynamic> e) {
    String? thumbnailUrl;
    List<Map<String, String?>> parsedVideos = [];

    if (e['videos'] != null && e['videos'] is List) {
      for (var v in e['videos']) {
        parsedVideos.add({
          'url': v['url']?.toString(),
          'og_image': v['og_image']?.toString(),
          'gender': v['gender']?.toString(),
          'angle': v['angle']?.toString(),
        });
      }
      if (parsedVideos.isNotEmpty) {
        final preferred = parsedVideos.firstWhere(
          (v) => v['gender'] == 'male' && v['angle'] == 'front',
          orElse: () => parsedVideos.first,
        );
        thumbnailUrl = preferred['og_image'];
      }
    } else {
      thumbnailUrl = e['og_image'];
    }

    return MuscleWikiExercise(
      id: e['id'] ?? 0,
      name: e['name'] ?? 'Unknown',
      thumbnailUrl: thumbnailUrl,
    );
  }
}

void main() async {
  final url = Uri.parse('https://api.musclewiki.com/exercises?limit=2');
  final headers = {
    'X-API-Key': 'mw_kvJEXdrK5ky8Mt6UfwdmZSWYy6ZHYOm2YxZV8CtySTM',
    'Accept': 'application/json'
  };

  final client = HttpClient();
  final req = await client.getUrl(url);
  headers.forEach((k, v) => req.headers.set(k, v));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  final decoded = jsonDecode(body);
  final resultsList = decoded['results'] as List;

  final futures = resultsList.map((e) async {
    final detailUrl = Uri.parse('https://api.musclewiki.com/exercises/${e["id"]}');
    final detailReq = await client.getUrl(detailUrl);
    headers.forEach((k, v) => detailReq.headers.set(k, v));
    final detailRes = await detailReq.close();
    final b = await detailRes.transform(utf8.decoder).join();
    return MuscleWikiExercise.mapper(jsonDecode(b));
  });

  final detailedList = await Future.wait(futures);
  for (var ex in detailedList) {
    print('ID: ${ex.id}, Name: ${ex.name}, Thumb: ${ex.thumbnailUrl}');
  }
  client.close();
}
