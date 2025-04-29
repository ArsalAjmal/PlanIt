import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Todo {
  String id;
  String title;
  bool completed;
  DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'createdAt': createdAt,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      completed: map['completed'] ?? false,
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
          snapshot.docs.map((doc) => Todo.fromMap(doc.data())).toList();

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

    try {
      // Update in Firestore
      await _firestore
          .collection('organizers')
          .doc(_userId)
          .collection('todos')
          .doc(todo.id)
          .update({'completed': updatedCompleted});

      // Update local state
      setState(() {
        todos[index].completed = updatedCompleted;
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
        backgroundColor: const Color(0xFFFFFDD0),
        appBar: AppBar(
          backgroundColor: const Color(0xFF9D9DCC),
          elevation: 0,
          title: const Text(
            'Todo List',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadTodos,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: 'Add a new task',
                                hintStyle: TextStyle(
                                  color: const Color(
                                    0xFF9D9DCC,
                                  ).withOpacity(0.6),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF9D9DCC),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF9D9DCC),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF9D9DCC),
                                    width: 2,
                                  ),
                                ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
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
                                itemCount: todos.length,
                                itemBuilder: (context, index) {
                                  return Card(
                                    elevation: 4,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: Checkbox(
                                        value: todos[index].completed,
                                        onChanged: (_) => _toggleTodo(index),
                                        activeColor: const Color(0xFF9D9DCC),
                                      ),
                                      title: Text(
                                        todos[index].title,
                                        style: TextStyle(
                                          decoration:
                                              todos[index].completed
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                          color: const Color(0xFF9D9DCC),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Color(0xFF9D9DCC),
                                        ),
                                        onPressed: () => _deleteTodo(index),
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
}
