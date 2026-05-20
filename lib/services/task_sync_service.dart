import 'task_api_service.dart';
import 'task_local_database.dart';

class TaskSyncService {
  static Future<void> loadInitialDataIfNeeded() async {
    if (!TaskLocalDatabase.isEmpty()) {
      return;
    }
    final tasks = await TaskApiService.fetchTasks();
    await TaskLocalDatabase.saveTasks(tasks);
  }
}