import 'package:flutter/material.dart';

class Task {
  final String title;
  final String deadline;
  bool done;
  final String priority;

  Task({
    required this.title,
    required this.deadline,
    required this.done,
    required this.priority,
  });
}

class TaskRepository {
  static List<Task> tasks = [
    Task(title: "Zrobić projekt", deadline: "jutro", done: false, priority: "wysoki"),
    Task(title: "Nauczyć się Fluttera", deadline: "dzisiaj", done: true, priority: "wysoki"),
    Task(title: "Zakupy", deadline: "piątek", done: false, priority: "średni"),
    Task(title: "Siłownia", deadline: "weekend", done: true, priority: "niski"),
  ];
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "KrakFlow",
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedFilter = "wszystkie";

  void _showDeleteDialog() {
    if (TaskRepository.tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lista zadań jest już pusta!")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Potwierdzenie"),
          content: const Text("Czy na pewno chcesz usunąć wszystkie zadania?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Anuluj"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  TaskRepository.tasks.clear();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Wszystkie zadania zostały usunięte")),
                );
              },
              child: const Text("Usuń", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int doneCount = TaskRepository.tasks.where((t) => t.done).length;

    List<Task> filteredTasks = TaskRepository.tasks;
    if (selectedFilter == "wykonane") {
      filteredTasks = TaskRepository.tasks.where((task) => task.done).toList();
    } else if (selectedFilter == "do zrobienia") {
      filteredTasks = TaskRepository.tasks.where((task) => !task.done).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("KrakFlow"),
        backgroundColor: Colors.blue.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showDeleteDialog,
            tooltip: "Usuń wszystkie zadania",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Masz dziś ${TaskRepository.tasks.length} zadań, wykonane: $doneCount",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFilterButton("wszystkie", "Wszystkie"),
                _buildFilterButton("do zrobienia", "Do zrobienia"),
                _buildFilterButton("wykonane", "Wykonane"),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Dzisiejsze zadania",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = filteredTasks[index];

                  return Dismissible(
                    key: ValueKey(task.title + TaskRepository.tasks.indexOf(task).toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      setState(() {
                        TaskRepository.tasks.remove(task);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Zadanie '${task.title}' usunięte")),
                      );
                    },
                    child: TaskCard(
                      title: task.title,
                      subtitle: "termin: ${task.deadline} | priorytet: ${task.priority}",
                      done: task.done,
                      onChanged: (bool? value) {
                        setState(() {
                          task.done = value ?? false;
                        });
                      },
                      onTap: () async {
                        final Task? updatedTask = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditTaskScreen(task: task),
                          ),
                        );

                        if (updatedTask != null) {
                          setState(() {
                            int originalIndex = TaskRepository.tasks.indexOf(task);
                            TaskRepository.tasks[originalIndex] = updatedTask;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final Task? newTask = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTaskScreen()),
          );

          if (newTask != null) {
            setState(() {
              TaskRepository.tasks.add(newTask);
            });
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterButton(String filterType, String label) {
    bool isActive = selectedFilter == filterType;
    return TextButton(
      onPressed: () {
        setState(() {
          selectedFilter = filterType;
        });
      },
      style: TextButton.styleFrom(
        foregroundColor: isActive ? Colors.blue : Colors.grey,
        textStyle: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
      ),
      child: Text(label),
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
  late TextEditingController titleController;
  late TextEditingController deadlineController;
  late TextEditingController priorityController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.task.title);
    deadlineController = TextEditingController(text: widget.task.deadline);
    priorityController = TextEditingController(text: widget.task.priority);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edytuj zadanie")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Tytuł zadania", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deadlineController,
              decoration: const InputDecoration(labelText: "Termin", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priorityController,
              decoration: const InputDecoration(labelText: "Priorytet", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final updatedTask = Task(
                  title: titleController.text,
                  deadline: deadlineController.text,
                  done: widget.task.done,
                  priority: priorityController.text,
                );
                Navigator.pop(context, updatedTask);
              },
              child: const Text("Zapisz zmiany"),
            ),
          ],
        ),
      ),
    );
  }
}

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final titleController = TextEditingController();
  final deadlineController = TextEditingController();
  final priorityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nowe zadanie")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Tytuł zadania", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deadlineController,
              decoration: const InputDecoration(labelText: "Termin (np. jutro)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priorityController,
              decoration: const InputDecoration(labelText: "Priorytet (wysoki/średni/niski)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final newTask = Task(
                  title: titleController.text,
                  deadline: deadlineController.text,
                  done: false,
                  priority: priorityController.text,
                );
                Navigator.pop(context, newTask);
              },
              child: const Text("Zapisz zadanie"),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.done,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: done ? Colors.grey.shade50 : Colors.white,
      child: ListTile(
        onTap: onTap,
        leading: Checkbox(
          value: done,
          onChanged: onChanged,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
            color: done ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: done ? Colors.grey.shade400 : Colors.black54,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}