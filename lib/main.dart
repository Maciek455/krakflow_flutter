import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'dart:math';
import 'models/task.dart';
import 'services/task_local_database.dart';
import 'services/task_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox("tasks");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeScreen(),
      theme: ThemeData(useMaterial3: true, primarySwatch: Colors.blue),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Task>> tasksFuture;
  String selectedFilter = "wszystkie";

  int allTasksCount = 0;
  int doneTasksCount = 0;
  int todoTasksCount = 0;

  @override
  void initState() {
    super.initState();
    tasksFuture = loadTasks();
  }

  Future<List<Task>> loadTasks() async {
    await TaskSyncService.loadInitialDataIfNeeded();
    return TaskLocalDatabase.getTasks();
  }

  void _refresh() {
    setState(() {
      tasksFuture = loadTasks();
    });
  }

  void updateCounters(List<Task> tasks) {
    setState(() {
      allTasksCount = tasks.length;
      doneTasksCount = tasks.where((task) => task.done).length;
      todoTasksCount = tasks.where((task) => !task.done).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KrakFlow Hive"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text("Usuń wszystkie zadania"),
                    content: const Text("Czy na pewno chcesz bezpowrotnie usunąć wszystkie zadania z bazy lokalnej?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Anuluj"),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Usuń"),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                await TaskLocalDatabase.deleteAllTasks();
                _refresh();
              }
            },
          )
        ],
      ),
      body: FutureBuilder<List<Task>>(
        future: tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Błąd: ${snapshot.error}"));

          final tasks = snapshot.data ?? [];

          WidgetsBinding.instance.addPostFrameCallback((_) {
            updateCounters(tasks);
          });

          List<Task> filtered = tasks;
          if (selectedFilter == "wykonane") filtered = tasks.where((t) => t.done).toList();
          if (selectedFilter == "do zrobienia") filtered = tasks.where((t) => !t.done).toList();

          return Column(
            children: [
              _buildCounterRow(),
              _buildFilterRow(),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    return Dismissible(
                      key: ValueKey(task.id),
                      onDismissed: (_) async {
                        await TaskLocalDatabase.deleteTask(task.id);
                        _refresh();
                      },
                      child: ListTile(
                        leading: Checkbox(
                          value: task.done,
                          onChanged: (value) async {
                            task.done = value ?? false;
                            await TaskLocalDatabase.updateTask(task);
                            _refresh();
                          },
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text("Termin: ${task.deadline} | Priorytet: ${task.priority}"),
                        onTap: () async {
                          final Task? updated = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => EditTaskScreen(task: task)),
                          );
                          if (updated != null) {
                            await TaskLocalDatabase.updateTask(updated);
                            _refresh();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Task? newTask = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTaskScreen()),
          );

          if (newTask != null) {
            await TaskLocalDatabase.addTask(newTask);
            _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCounterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text("Wszystkie: $allTasksCount", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("Do zrobienia: $todoTasksCount", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          Text("Wykonane: $doneTasksCount", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ["wszystkie", "do zrobienia", "wykonane"].map((f) => TextButton(
        onPressed: () => setState(() => selectedFilter = f),
        child: Text(f, style: TextStyle(color: selectedFilter == f ? Colors.blue : Colors.grey)),
      )).toList(),
    );
  }
}

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _deadlineController = TextEditingController();
  String _selectedPriority = "średni";

  @override
  void dispose() {
    _titleController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dodaj nowe zadanie")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Nazwa zadania", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deadlineController,
              decoration: const InputDecoration(labelText: "Termin (np. dzisiaj, 25 maja)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: const InputDecoration(labelText: "Priorytet", border: OutlineInputBorder()),
              items: ["niski", "średni", "wysoki"].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) => setState(() => _selectedPriority = value ?? "średni"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                if (_titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nazwa zadania nie może być pusta!")),
                  );
                  return;
                }

                final newTask = Task(
                  id: Random().nextInt(1000000),
                  title: _titleController.text.trim(),
                  deadline: _deadlineController.text.trim().isEmpty ? "brak" : _deadlineController.text.trim(),
                  done: false,
                  priority: _selectedPriority,
                );

                Navigator.pop(context, newTask);
              },
              child: const Text("Dodaj zadanie", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class EditTaskScreen extends StatefulWidget {
  final Task task;
  const EditTaskScreen({super.key, required this.task});

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  late TextEditingController _titleController;
  late TextEditingController _deadlineController;
  late String _selectedPriority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _deadlineController = TextEditingController(text: widget.task.deadline);
    _selectedPriority = widget.task.priority;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edytuj zadanie")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Nazwa zadania", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deadlineController,
              decoration: const InputDecoration(labelText: "Termin", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: const InputDecoration(labelText: "Priorytet", border: OutlineInputBorder()),
              items: ["niski", "średni", "wysoki"].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (value) => setState(() => _selectedPriority = value ?? "średni"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                if (_titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nazwa zadania nie może być pusta!")),
                  );
                  return;
                }

                widget.task.title = _titleController.text.trim();
                widget.task.deadline = _deadlineController.text.trim().isEmpty ? "brak" : _deadlineController.text.trim();
                widget.task.priority = _selectedPriority;

                Navigator.pop(context, widget.task);
              },
              child: const Text("Zapisz zmiany", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}