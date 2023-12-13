import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SelectedUsers()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Journey'),
    );
  }
}

class SelectedUsers extends ChangeNotifier {
  List<dynamic> _users = [];

  void addUser(Map<String, dynamic> user) {
    _users.add(user);
    notifyListeners();
  }

  void removeUser(Map<String, dynamic> user) {
    _users.remove(user);
    notifyListeners();
  }
  
  bool containsUser(String id) {
    for (var user in _users) {
      if (user['id'] == id) {
        return true;
      }
    }
    return false;
  }

  List<dynamic> get users => _users;
}

class AuthProvider extends ChangeNotifier {
  String? _accessToken;

  AuthProvider() {
    loadToken();
  }

  Future<void> loadToken() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
  } catch (e) {
    print('Error loading token: $e');
  }
}

  Future<void> setAccessToken(String? token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      prefs.setString('accessToken', token);
    } else {
      prefs.remove('accessToken');
    }
    notifyListeners();
  }

  String? get accessToken => _accessToken;
}

class MyHomePage extends StatelessWidget {
  final String title;
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return FutureBuilder(
      future: authProvider.loadToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Show loading indicator while waiting for loadToken to complete
        } else {
          if (authProvider.accessToken != null) {
            return const UsersView(title: 'Users',); // If accessToken is not null, navigate to UsersView
          } else {
            return DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(title),
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'Login'),
                      Tab(text: 'Signup'),
                    ],
                  ),
                ),
                body: const TabBarView(
                  children: [
                    LoginView(title: 'Login'),
                    SignupView(title: 'Signup'),
                  ],
                ),
              ),
            ); // If accessToken is null, show the login/signup view
          }
        }
      },
    );
  }
}

class ApiRequest {
  static Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$apiUrl/api/v1/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(<String, String>{
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['accessToken'];
    } else {
      throw Exception(response.body);
    }
  }

  static Future<Map<String, dynamic>> signup(String name, String lastname, String email,
      String password, XFile? imageFile) async {
    final uri = Uri.parse('$apiUrl/api/v1/users');
    final request = html.HttpRequest();
    request.open('POST', uri.toString());
    final formData = html.FormData();
    formData.append('name', name);
    formData.append('lastname', lastname);
    formData.append('email', email);
    formData.append('password', password);
    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      final blob = html.Blob([bytes]);
      formData.appendBlob('avatar', blob);
    }

    request.send(formData);

    await request.onLoadEnd.firstWhere((event) => event.loaded == event.total);

    if (request.status == 200) {
      final data = jsonDecode(request.responseText!);
      return data;
    } else {
      print('Error: ${request.responseText}');
      final data = jsonDecode(request.responseText!);
      return data;
    }
  }

  //get all users
  static Future<List<dynamic>> getUsers(String token) async {
    final response = await http.get(
      Uri.parse('$apiUrl/api/v1/users'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        'Authorization': token,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'];
    } else {
      throw Exception(response.body);
    }
  }
}

class SignupView extends StatefulWidget {
  final String title;

  const SignupView({super.key, required this.title});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _lastname = '';
  String _email = '';
  String _password = '';
  XFile? _imageFile;
  String? imageUrl;

  String? emailError;

  void createImageUrl() {
    if (_imageFile != null) {
      setState(() {
        imageUrl = _imageFile!.path;
      });
    }
  }

  Future<void> pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    setState(() {
      _imageFile = image;
    });

    createImageUrl();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              
              imageUrl != null ? 
              Align(
                  alignment: Alignment.center,
                  child:
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 200,
                  height: 200,
                  child:
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child:
                GestureDetector(
                  onTap: () async {
                  await pickImage();
                },
                child:
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.network(
                    imageUrl!, 
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
          ))))) :
           MouseRegion(
            cursor: SystemMouseCursors.click,
            child:
           GestureDetector(
            onTap: () async {
                  await pickImage();
                },
                child:
          CircleAvatar(
            child: Text(_name != '' ? _name[0].toUpperCase() : 'New'),
            radius: 100,
      ))),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                onSaved: (value) => _name = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name.';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Lastname'),
                onSaved: (value) => _lastname = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your lastname.';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                onSaved: (value) => _email = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email.';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                onSaved: (value) => _password = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password.';
                  } else if (value.length < 8) {
                    return 'Password must be at least 8 characters.';
                  }
                  return null;
                },
              ),
              
              ElevatedButton(
                onPressed: () async {
                  final form = _formKey.currentState!;
                  final navigator = Navigator.of(context);
                  if (form.validate()) {
                    form.save();
                    try {
                      final response = await ApiRequest.signup(
                          _name, _lastname, _email, _password, _imageFile);
                      navigator.push(
                        MaterialPageRoute(builder: (context) => LoginView(title: 'Login')),
                      );
                    } catch (e) {
                      print('Error: $e');
                    }
                  } else {
                    print('Invalid form');
                  }
                },
                child: const Text('Signup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class LoginView extends StatefulWidget {
  final String title;

  const LoginView({super.key, required this.title});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String? emailError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                onSaved: (value) => _email = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email.';
                  } else if (emailError != null) {
                    final msg = emailError;
                    emailError = null;
                    return msg;
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                onSaved: (value) => _password = value!,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password.';
                  } else if (value.length < 8) {
                    return 'Password must be at least 8 characters.';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  final form = _formKey.currentState!;
                  if (form.validate()) {
                    form.save();
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final navigator = Navigator.of(context);
                    try {
                      final response =
                          await ApiRequest.login(_email, _password);
                      final token = response;
                      authProvider.setAccessToken(token);
                      navigator.push(
                        MaterialPageRoute(builder: (context) => UsersView(title: 'Users')),
                      );
                    } catch (e) {
                      // the e contains a JSON object with the errors, but its a string
                      // so we need to convert it to a Map<String, dynamic>
                      print('Error: $e');
                      /*
                      Exception: {"errors":[{"type":"field","value":"luism.sanchezp@autonoma.edu.com","msg":"email is not registered","path":"email","location":"body"},{"type":"field","value":"luism.sanchezp@autonoma.edu.com","msg":"email is not from a valid domain.","path":"email","location":"body"}]}
                      get rid of the Exception: part
                      
                      */
                      String errorMessage = e.toString();
                      if (errorMessage.startsWith('Exception: ')) {
                        errorMessage = errorMessage.substring('Exception: '.length);
                      }
                      
                      final errors = jsonDecode(errorMessage.toString())['errors'];
                      for (var error in errors) {
                        if (error['path'] == 'email') {
                          setState(() {
                            emailError = error['msg'];
                          });
                          break;
                        }
                      }
                    }
                  } else {
                    print('Invalid form');
                  }
                },
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UsersView extends StatefulWidget {
  final String title;

  const UsersView({super.key, required this.title});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;
    try {
      final users = await ApiRequest.getUsers(token!);
      setState(() {
        _users = users;
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  Widget buildUserCard(Map<String, dynamic> user) {
    var letter = 'U';
    if (user['profile'] != null) {
      letter = user['profile']['pro_nombre'][0];
    }

  var avatar = user['profile'] != null ? user['profile']['pro_avatar'] : null;
  var name = user['profile'] != null ? user['profile']['pro_nombre'] : "No name";
  var lastname = user['profile'] != null ? user['profile']['pro_apelli'] : "No lastname";
  var email = user['email'];
  var role = user['role'][0];
  var active = user['active'];

  final _selectedUsers = Provider.of<SelectedUsers>(context);

  return Card(
      child: ListTile(
        leading: avatar != null ? ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Image.network(
          avatar, 
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          ),
        ) : CircleAvatar(
      child: Text(letter),
      radius: 25,
    ),
        title: Text('$name $lastname'),
        subtitle: Text(role == 'admin' ? 'Administrator' : role == 'professional' ? 'Professional' : role == 'user' ? 'User' : 'Unknown', style: const TextStyle(color: Colors.grey)),
        //role Chip and add to SelectedUsers button
        trailing: ElevatedButton(
              onPressed: () {
                if (!_selectedUsers.containsUser(user['id'])) {
                  _selectedUsers.addUser(user);
                }
              },
              child: Text(_selectedUsers.containsUser(user['id']) ? 'Selected' : 'Add'),
            ),

      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              prefs.remove('accessToken'); // Remove the accessToken from SharedPreferences
              authProvider.setAccessToken(null); // Remove the accessToken from AuthProvider
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Journey')),
                (route) => false,
              ); // Navigate to the login/signup view and remove all previous routes
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              navigator.push(
                MaterialPageRoute(builder: (context) => const SelectedUsersView(title: 'Selected Users')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return buildUserCard(user);
        },
      ),
    );
  }
}

class _SelectedUsersListView extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    var list = context.watch<SelectedUsers>();
    return ListView.builder(
      itemCount: list.users.length,
      itemBuilder: (context, index) {
        final user = list.users[index];
        return ListTile(
          leading: user['profile'] != null ? ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Image.network(
          user['profile']['pro_avatar'],
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          ),
        ) : CircleAvatar(
      child: Text(user['profile']['pro_nombre'][0]),
      radius: 25,
    ),
          title: Text('${user['profile']['pro_nombre']} ${user['profile']['pro_apelli']}'),
          subtitle: Text(user['email']),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle),
            onPressed: () {
              list.removeUser(user);
            },
          ),
        );
      },
    );
  }
}

class SelectedUsersView extends StatelessWidget {
  final String title;

  const SelectedUsersView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: _SelectedUsersListView(),
    );
  }
}
