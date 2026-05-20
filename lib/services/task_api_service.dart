import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class TaskApiService {
  static const String baseUrl = "https://dummyjson.com";

  static Future<List<Task>> fetchTasks() async {
    final response = await http.get(Uri.parse("$baseUrl/todos"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List todos = data["todos"];
      final random = Random();

      return todos.map((todo) {
        return Task(
          id: todo["id"],
          title: todo["todo"],
          deadline: "${random.nextInt(30) + 1} maja",
          done: todo["completed"],
          priority: "średni",
        );
      }).toList();
    } else {
      throw Exception("Błąd pobierania danych z API");
    }
  }
}