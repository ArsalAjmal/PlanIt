import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';

class Todo {
  String id;
  String title;
  bool completed;
  String status; // Add status field: 'todo', 'inProgress', 'done'
  DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    required this.completed,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'status': status,
      'createdAt': createdAt,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      completed: map['completed'] ?? false,
      status: map['status'] ?? 'todo',
      createdAt:
          (map['createdAt'] is Timestamp)
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }
}

class OrganizerTodoScreen extends StatefulWidget {
  const OrganizerTodoScreen({super.key});

  @override
  _OrganizerTodoScreenState createState() => _OrganizerTodoScreenState();
}

class _OrganizerTodoScreenState extends State<OrganizerTodoScreen> {
  List<Todo> todos = [];
  String _selectedStatus = 'todo'; // Default selected status
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getUserIdAndLoadTodos();
  }

  Future<void> _getUserIdAndLoadTodos() async {
    final user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
      await _loadTodos();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_userId == null) return;

      final snapshot =
          await _firestore
              .collection('organizers')
              .doc(_userId)
              .collection('todos')
              .orderBy('createdAt', descending: true)
              .get();

      final loadedTodos =
          snapshot.docs.map((doc) {
            final data = doc.data();
            // Ensure each todo has a status field, defaults to 'todo' if missing
            if (!data.containsKey('status')) {
              data['status'] = data['completed'] ? 'done' : 'todo';
            }
            return Todo.fromMap(data);
          }).toList();

      setState(() {
        todos = loadedTodos;
        _isLoading = false;
      });

      print('Loaded ${todos.length} todos for organizer $_userId');
    } catch (e) {
      print('Error loading todos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addTodo() async {
    if (_controller.text.isEmpty || _userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Create new todo with unique ID
      final todoId =
          _firestore
              .collection('organizers')
              .doc(_userId)
              .collection('todos')
              .doc()
              .id;

      final newTodo = Todo(
        id: todoId,
        title: _controller.text,
        completed: false,
        status: _selectedStatus, // Use the selected status
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore
          .collection('organizers')
          .doc(_userId)
          .collection('todos')
          .doc(todoId)
          .set(newTodo.toMap());

      // Update local state
      setState(() {
        todos.insert(0, newTodo); // Add to the beginning of the list
        _controller.clear();
        _isLoading = false;
      });
    } catch (e) {
      print('Error adding todo: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error adding task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleTodo(int index) async {
    if (_userId == null) return;

    final todo = todos[index];
    final updatedCompleted = !todo.completed;
    final updatedStatus = updatedCompleted ? 'done' : todo.status;

    try {
      // Update in Firestore
      await _firestore
          .collection('organizers')
          .doc(_userId)
          .collection('todos')
          .doc(todo.id)
          .update({'completed': updatedCompleted, 'status': updatedStatus});

      // Update local state
      setState(() {
        todos[index].completed = updatedCompleted;
        todos[index].status = updatedStatus;
      });
    } catch (e) {
      print('Error updating todo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTodoStatus(int index, String newStatus) async {
    if (_userId == null) return;

    final todo = todos[index];
    // If marking as done, also update completed status
    final updatedCompleted = newStatus == 'done' ? true : todo.completed;

    try {
      // Update in Firestore
      await _firestore
          .collection('organizers')
          .doc(_userId)
          .collection('todos')
          .doc(todo.id)
          .update({'status': newStatus, 'completed': updatedCompleted});

      // Update local state
      setState(() {
        todos[index].status = newStatus;
        todos[index].completed = updatedCompleted;
      });
    } catch (e) {
      print('Error updating todo status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating task status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTodo(int index) async {
    if (_userId == null) return;

    final todo = todos[index];

    try {
      // Delete from Firestore
      await _firestore
          .collection('organizers')
          .doc(_userId)
          .collection('todos')
          .doc(todo.id)
          .delete();

      // Update local state
      setState(() {
        todos.removeAt(index);
      });
    } catch (e) {
      print('Error deleting todo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error deleting task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Get counts for each status
  int get todoCount => todos.where((todo) => todo.status == 'todo').length;
  int get inProgressCount =>
      todos.where((todo) => todo.status == 'inProgress').length;
  int get doneCount => todos.where((todo) => todo.status == 'done').length;

  @override
  Widget build(BuildContext context) {
    // Set status bar color to match background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFFFFDE5),
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.creamBackground,
        appBar: null,
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF9D9DCC),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'Todo List',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            onPressed: _loadTodos,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),

                    // My Tasks section with categories - moved to top
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'My Tasks',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Task categories
                          Row(
                            children: [
                              Expanded(
                                child: _buildTaskCategoryCard(
                                  'To Do',
                                  todoCount,
                                  'todo',
                                  Colors.redAccent,
                                  Icons.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTaskCategoryCard(
                                  'In Progress',
                                  inProgressCount,
                                  'inProgress',
                                  Colors.orangeAccent,
                                  Icons.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTaskCategoryCard(
                                  'Done',
                                  doneCount,
                                  'done',
                                  Colors.green,
                                  Icons.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Input field moved below My Tasks section - only visible when Todo is selected
                    Visibility(
                      visible: _selectedStatus == 'todo',
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                decoration: InputDecoration(
                                  labelText: 'Task',
                                  hintText: 'Add a new task',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.withOpacity(0.1),
                                  labelStyle: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.task_alt,
                                    color: Color(0xFF9D9DCC),
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10.0,
                                    horizontal: 12.0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF9D9DCC),
                                      width: 1,
                                    ),
                                  ),
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                                onSubmitted: (_) => _addTodo(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: _addTodo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9D9DCC),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child:
                          todos.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      size: 48,
                                      color: Color(0xFF9D9DCC),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No tasks yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Color(0xFF9D9DCC),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Add a task to get started',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: _filteredTodos.length,
                                itemBuilder: (context, index) {
                                  final todo = _filteredTodos[index];
                                  return Card(
                                    elevation: 4,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading:
                                          todo.status == 'done'
                                              ? Container(
                                                width: 10,
                                                height: 10,
                                                margin: const EdgeInsets.all(8),
                                                decoration: const BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                              : todo.status == 'inProgress'
                                              ? Container(
                                                width: 10,
                                                height: 10,
                                                margin: const EdgeInsets.all(8),
                                                decoration: const BoxDecoration(
                                                  color: Colors.orangeAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                              : Container(
                                                width: 10,
                                                height: 10,
                                                margin: const EdgeInsets.all(8),
                                                decoration: const BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                      title: Text(
                                        todo.title,
                                        style: TextStyle(
                                          decoration:
                                              todo.status == 'done'
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PopupMenuButton<String>(
                                            icon: const Icon(
                                              Icons.more_vert,
                                              color: Colors.black87,
                                            ),
                                            onSelected: (String value) {
                                              if (value == 'delete') {
                                                _deleteTodo(
                                                  todos.indexOf(todo),
                                                );
                                              } else {
                                                _updateTodoStatus(
                                                  todos.indexOf(todo),
                                                  value,
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (BuildContext context) => [
                                                  const PopupMenuItem(
                                                    value: 'todo',
                                                    child: Text('To Do'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'inProgress',
                                                    child: Text('In Progress'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'done',
                                                    child: Text('Done'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Delete'),
                                                  ),
                                                ],
                                            color: Colors.white,
                                            elevation: 3,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
    );
  }

  // Get filtered todos based on selected status
  List<Todo> get _filteredTodos =>
      _selectedStatus == 'all'
          ? todos
          : todos.where((todo) => todo.status == _selectedStatus).toList();

  // Build task category card
  Widget _buildTaskCategoryCard(
    String title,
    int count,
    String status,
    Color iconColor,
    IconData iconData,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color:
              _selectedStatus == status
                  ? iconColor.withOpacity(0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _selectedStatus == status
                    ? iconColor
                    : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconData, color: iconColor, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              count > 0 ? '$count tasks' : 'No tasks',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
