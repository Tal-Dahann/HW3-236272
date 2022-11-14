import 'dart:developer';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const MyApp();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

enum Status { authenticated, authenticating, unauthenticated }

class AuthNotifier extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  Status _status = Status.unauthenticated;

  Status get status => _status;

  User? get user => _user;

  AuthNotifier() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        _status = Status.unauthenticated;
      } else {
        _user = firebaseUser;
        _status = Status.authenticated;
      }
      notifyListeners();
    });
  }

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.authenticating;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print(e);
      _status = Status.unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return true;
    } catch (e) {
      print(e);
      _status = Status.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _auth.signOut();
    _status = Status.unauthenticated;
    notifyListeners();
  }
}

class SavedNotifier extends ChangeNotifier {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Set<String> _saved = <String>{};
  AuthNotifier auth;

  SavedNotifier(this.auth);

  Set<String> get saved => _saved;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _update(false);
  }

  bool add(String pair) {
    if (_saved.add(pair)) {
      notifyListeners();
      return true;
    } else {
      return false;
    }
  }

  bool remove(String pair) {
    if (_saved.remove(pair)) {
      notifyListeners();
      return true;
    } else {
      return false;
    }
  }

  Future<void> _update(bool merge) async {
    if (auth.status == Status.authenticated) {
      if (merge) {
        var prevDoc =
            await _firestore.collection('Users').doc(auth.user?.uid).get();
        _saved.addAll(((prevDoc.data()?['saved'] ?? <String>[]) as List)
            .map((element) => element as String));
      }
      await _firestore.collection('Users').doc(auth.user?.uid).set(
        {
          'saved': _saved.toList(),
        },
        SetOptions(merge: true),
      );
      if (merge) {
        notifyListeners();
      }
    }
  }

  SavedNotifier update(AuthNotifier newAuth) {
    auth = newAuth;
    _update(true);
    return this;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthNotifier()),
        ChangeNotifierProxyProvider<AuthNotifier, SavedNotifier>(
            create: (context) => SavedNotifier(context.read<AuthNotifier>()),
            update: (context, auth, saved) {
              if (saved != null) {
                return saved.update(auth);
              } else {
                return SavedNotifier(auth);
              }
            }),
      ],
      child: MaterialApp(
        title: 'Startup Name Generator',
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
        home: const RandomWords(),
      ),
    );
  }
}

class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <String>[];
  final _biggerFont = const TextStyle(fontSize: 18);
  final wordPair = WordPair.random();
  final _snappingSheetController = SnappingSheetController();

  Future<bool?> showAlertDialog(String toDelete) {
    AlertDialog alert = AlertDialog(
      title: const Text('Delete Suggestion'),
      content: Text(
        'Are you sure you want to delete $toDelete from your saved suggestions?',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.deepPurple,
          ),
          child: const Text(
            'Yes',
            style: TextStyle(color: Colors.white),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.deepPurple,
          ),
          child: const Text(
            'No',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
    return showDialog<bool?>(
      context: context,
      builder: (BuildContext context) => alert,
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) {
        final tiles = context.watch<SavedNotifier>().saved.map(
          (pair) {
            return Dismissible(
              background: Container(
                color: Colors.deepPurple,
                child: Row(
                  children: const [
                    Icon(Icons.delete, color: Colors.white),
                    Text(
                      'Delete Suggestion',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              key: ValueKey(pair),
              confirmDismiss: (_) => showAlertDialog(pair),
              onDismissed: (_) => context.read<SavedNotifier>().remove(pair),
              direction: DismissDirection.horizontal,
              child: ListTile(
                title: Text(
                  pair,
                  style: _biggerFont,
                ),
              ),
            );
          },
        );

        final divided = tiles.isNotEmpty
            ? ListTile.divideTiles(
                tiles: tiles,
                context: context,
              ).toList()
            : <Widget>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Saved Suggestions'),
          ),
          body: ListView(
            children: divided,
          ),
        );
      }),
    );
  }

  // Future<bool> _confirmDeletionDismissFunc(
  //     DismissDirection direction, WordPair pair) async {
  //   // SnackBar deleteButton = const SnackBar(
  //   //   content: Text('Deletion is not implemented yet.'),
  //   //   duration: Duration(seconds: 3),
  //   //   padding: EdgeInsets.all(15.0),
  //   // );
  //   // //log('test');
  //   // ScaffoldMessenger.of(context).showSnackBar(deleteButton);
  //   bool ret = showAlertDialog(pair.asPascalCase);
  //   return Future.value(false);
  //}

  void _pushLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Login'),
            ),
            body: const LoginPage(),
          );
        },
      ),
    );
  }

  void _onLogOutPress() {
    context.read<AuthNotifier>().signOut();
  }

  bool isSnapPressed = false;
  var initPos;

  Widget ItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, i) {
        //for odd tiles, we just return a divider.
        if (i.isOdd) return const Divider();

        final index = i ~/ 2;
        //generateWordPairs().take(10) returns 10 random word pairs
        //we then add all of those to _suggestions
        if (index >= _suggestions.length) {
          _suggestions
              .addAll(generateWordPairs().take(10).map((e) => e.asPascalCase));
        }
        final alreadySaved =
            context.watch<SavedNotifier>().saved.contains(_suggestions[index]);
        return ListTile(
          title: Text(
            _suggestions[index],
            style: _biggerFont,
          ),
          trailing: Icon(
            alreadySaved ? Icons.favorite : Icons.favorite_border,
            color: alreadySaved ? Colors.red : null,
            semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
          ),
          onTap: () {
            setState(() {
              if (alreadySaved) {
                context.read<SavedNotifier>().remove(_suggestions[index]);
              } else {
                context.read<SavedNotifier>().add(_suggestions[index]);
              }
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Status currStatus = context.watch<AuthNotifier>().status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
          IconButton(
            onPressed: (currStatus == Status.unauthenticated)
                ? _pushLogin
                : _onLogOutPress,
            icon: (currStatus == Status.unauthenticated)
                ? const Icon(Icons.login)
                : const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      body: (currStatus == Status.authenticated)
          ? SafeArea(
              bottom: false,
              child: SnappingSheet(
                snappingPositions: [
                  const SnappingPosition.factor(
                      positionFactor: 0,
                      grabbingContentOffset: GrabbingContentOffset.top),
                  const SnappingPosition.factor(positionFactor: 0.2),
                ],
                controller: _snappingSheetController,
                grabbingHeight: 50,
                grabbing: InkWell(
                  onTap: () {
                    if (!isSnapPressed) {
                      initPos = _snappingSheetController.currentPosition;
                      _snappingSheetController.snapToPosition(
                          const SnappingPosition.factor(positionFactor: 0.20));
                      isSnapPressed = true;
                    } else {
                      _snappingSheetController.snapToPosition(
                          const SnappingPosition.factor(
                              positionFactor: 0,
                              grabbingContentOffset:
                                  GrabbingContentOffset.top));
                      isSnapPressed = false;
                    }
                  },
                  child: Container(
                    color: Colors.blueGrey.shade100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          "Welcome back, ${context.watch<AuthNotifier>().user!.email}",
                          style: const TextStyle(fontSize: 15),
                        ),
                        const Icon(Icons.keyboard_arrow_up)
                      ],
                    ),
                  ),
                ),
                sheetBelow: SnappingSheetContent(
                  sizeBehavior: SheetSizeStatic(size: MediaQuery.of(context).size.height, expandOnOverflow: false),
                  draggable: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          Container(
                            transformAlignment: FractionalOffset.topCenter,
                            height: 120,
                          child: Row(
                              //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const Flexible(
                                    fit: FlexFit.tight,
                                    flex: 2,
                                    child: CircleAvatar(
                                      backgroundImage: AssetImage('images/blank profile picture.jpg'),
                                      radius: 35,
                                    )),
                                const Padding(padding: EdgeInsets.only(left:20)),
                                Flexible(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Flexible(
                                        flex: 3,
                                        child: Text(
                                          '${context.read<AuthNotifier>().user!.email}',
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400),
                                        ),
                                      ),
                                      Flexible(
                                        flex: 1,
                                        child: ElevatedButton(
                                          child: Container(
                                            color: Colors.blue,
                                            child: const Text(
                                              'Change Avatar',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w400),
                                            ),
                                          ),
                                          onPressed:
                                              () {}, //! ADD CHANGE AVATAR BUTTON
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height*0.5,)
                        ],
                      ),
                    ),
                  ),
                ),
                child: ItemsList(),
              ),
            )
          : ItemsList(),
    );
  }
}

////////////////LOGIN PAGE WIDGET////////////////

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailField = TextEditingController();
  final _passwordField = TextEditingController();
  final _confirmPassword = TextEditingController();

  void displayFailSnackbar(String failString) {
    SnackBar failedSnackbar = SnackBar(
      content: Text(failString),
      duration: const Duration(seconds: 3),
      padding: const EdgeInsets.all(15.0),
    );
    ScaffoldMessenger.of(context).showSnackBar(failedSnackbar);
  }

  void _onLoginButtonPress() async {
    String email = _emailField.text.toString();
    String password = _passwordField.text.toString();
    bool ret = await context.read<AuthNotifier>().signIn(email, password);
    if (ret == false) {
      //display snackbar of failed login 'There was an error logging into the app'
      displayFailSnackbar('There was an error logging into the app');
    } else {
      //print(ret);
      Navigator.of(context).pop();
    }
  }

  void _onSignUpButtonPress() async {
    String email = _emailField.text.toString();
    String password = _passwordField.text.toString();
    //Disply bottom sheet modal and confirm password here
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.25 +
                MediaQuery.of(context).viewInsets.bottom,
            child: Column(
              children: [
                const Padding(padding: EdgeInsets.only(top: 10)),
                const Text('Please confirm your password below:'),
                const Divider(
                  thickness: 2,
                  endIndent: 40,
                  indent: 40,
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextFormField(
                    controller: _confirmPassword,
                    obscureText: true,
                    decoration: InputDecoration(hintText: 'Re-Enter Password'),
                  ),
                ),
                ElevatedButton(
                    onPressed: () async {
                      UserCredential? ret = await context
                          .read<AuthNotifier>()
                          .signUp(email, password);
                      if (ret == null) {
                        //displayFailedSignup
                        displayFailSnackbar(
                            'There was an error Signing-Up to the app');
                      } else {
                        //print(ret);
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.25,
                      color: Colors.blue,
                      child: const Center(child: Text('Confirm')),
                    ))
              ],
            ),
          );
        });
    //
  }

  @override
  Widget build(BuildContext context) {
    Status currStatus = context.watch<AuthNotifier>().status;

    return Scaffold(
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(10.0),
          ),
          const Text('Welcome to startup Names Generator! Please log in:'),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextField(
              controller: _emailField,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Email'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              bottom: 50.0,
            ),
            child: TextField(
              controller: _passwordField,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ),
          /* Login button: */
          ((currStatus == Status.unauthenticated)
              ? TextButton(
                  onPressed: _onLoginButtonPress,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.only(
                      left: 60.0,
                      right: 60.0,
                      top: 10.0,
                      bottom: 10.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9.0),
                      color: Colors.deepPurple,
                    ),
                    child: const Center(
                      child:
                          Text('Log In', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: LinearProgressIndicator(),
                )),
          /* Sign Up button: */
          ((currStatus == Status.unauthenticated)
              ? TextButton(
                  onPressed: _onSignUpButtonPress, // ! Change to _onSignUpPress
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.only(
                      left: 60.0,
                      right: 60.0,
                      top: 10.0,
                      bottom: 10.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9.0),
                      color: Colors.blue,
                    ),
                    child: const Center(
                      child: Text('New user? Click to sign up',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: LinearProgressIndicator(),
                )),
        ],
      ),
    );
  }
}
