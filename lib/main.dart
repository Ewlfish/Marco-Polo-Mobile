import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const googleApiKey = 'AIzaSyDHGausYXQKBnImesjovCELmkABJI-ySvc';
const geminiApiKey = 'AIzaSyCb46HFdBzoto-E4LDlF2PoK6fWHM7B75Q';

void main() {
  runApp(SidequestApp());
}

class SidequestApp extends StatelessWidget {
  const SidequestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Sidequest Generator', home: SidequestHome());
  }
}

class SidequestHome extends StatefulWidget {
  const SidequestHome({super.key});

  @override
  _SidequestHomeState createState() => _SidequestHomeState();
}

class _SidequestHomeState extends State<SidequestHome> {
  String _sidequests = 'Press the button to get quests!';
  List<String> _completedQuests = [];
  int _selectedTab = 0;
  String _story = '';
  bool _isGeneratingStory = false;

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          "User denied permissions to access the device's location.",
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<List<String>> _getNearbyPlaces(Position position) async {
    // Combine multiple types for richer results
    final types = [
      'cafe',
      'restaurant',
      'park',
      'store',
      'museum',
      'tourist_attraction',
      'point_of_interest',
    ];

    // Build a list of futures for each type
    final futures = types.map((type) async {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${position.latitude},${position.longitude}'
        '&radius=1000&type=$type&key=$googleApiKey',
      );
      final response = await http.get(url);
      final data = json.decode(response.body);
      if (data['results'] == null) return <String>[];
      return List<String>.from(
        data['results'].map((e) => e['name'] ?? 'Unnamed Place'),
      );
    });

    // Wait for all requests and combine results
    final results = await Future.wait(futures);
    final allPlaces = results
        .expand((x) => x)
        .toSet()
        .toList(); // Remove duplicates

    // Limit to 10 unique places
    return allPlaces.take(30).toList();
  }

  Map<String, String> extractSidequestParts(String response) {
    final lines = response.split('\n');

    String location = '';
    String title = '';
    String objective = '';
    String lore = '';
    String quest = '';

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Location:')) {
        location = trimmed.replaceFirst('Location:', '').trim();
      } else if (trimmed.startsWith('Title:')) {
        title = trimmed.replaceFirst('Title:', '').trim();
      } else if (trimmed.startsWith('Objective:')) {
        objective = trimmed.replaceFirst('Objective:', '').trim();
      } else if (trimmed.startsWith('Lore:')) {
        lore = trimmed.replaceFirst('Lore:', '').trim();
      } else if (trimmed.startsWith('Quest:')) {
        quest = trimmed.replaceFirst('Quest:', '').trim();
      }
    }

    return {
      'location': location,
      'title': title,
      'objective': objective,
      'lore': lore,
      'quest': quest,
    };
  }

  Future<String> _generateSidequests(List<String> places) async {
    final prompt =
        '''
I'm building an app that generates fun little sidequests based on real-world locations.
Given these nearby places, pick three different locations and create sidequests for them based on the given format:
${places.join(', ')}

You are an RPG quest designer creating themed exploration missions for a real-world location for an app that gamifies exploring locations and there are "main quests" which are main locations like (statue of liberty, central park, the met), and then "side quests" (buy a taco from los tacos, take a picture next to a certain mural, get a coffee from this coffee shop). Here are some examples:
Quest: St. Patrick's Cathedral: 
    Location: "St. Patrick’s Cathedral"
    Objective: "Step inside and observe the stained glass."
    Title: "Sanctum of Stone and Sky"
    Lore: "A holy refuge where even the concrete heart of the city finds peace."

Quest: NYPL Bryant Park:
  Location: "New York Public Library - Main Branch"
  Objective: "Find the stone lions (Patience and Fortitude) and venture inside."
  Title: "The People’s Citadel"
  Lore: "Guarded by silent lions, this archive holds the whispers of civilizations."
  
Quest: Empire State Building:
  Location: "Empire State Building"
  Objective: "Reach the observation deck or stand at its base and look up."
  Title: "Skyrise Trial"
  Lore: "Ascend the tower of dreams and face the wind that crowns kings and monsters alike."

Quest: One World Trade:
  Location: "One World Trade Center & 9/11 Memorial"
  Objective: "Reflect at the twin fountains and look upward to the tower."
  Title: "Beacon of Echoes"
  Lore: "Where loss met unity, a new tower pierces the clouds to honor the fallen."

For each mission, follow this exact format: 

Quest: [Landmark Name]:
  Location: [Short location name]
  Objective: [Clear, feasible, and simple action the user must complete there] 
  Title: [Creative RPG-style quest title]
  Lore: [One to two sentence fantasy-style lore, poetic or mysterious in tone]

The quests should mix well-known locations (like monuments, parks, or buildings) with more unique or local spots (like cafes, cemeteries, or small businesses). Keep the descriptions concise but imaginative. Do not add anything before or after the specified format.
''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$geminiApiKey',
    );

    final body = json.encode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    print("Gemini raw response: ${response.body}");

    final data = json.decode(response.body);

    if (data == null ||
        data['candidates'] == null ||
        data['candidates'].isEmpty) {
      throw Exception(
        "Gemini API returned no content: ${data['error'] ?? 'Unknown error'}",
      );
    }

    final content = data['candidates'][0]['content'];
    if (content == null ||
        content['parts'] == null ||
        content['parts'].isEmpty) {
      throw Exception("Gemini content format is unexpected.");
    }

    return content['parts'][0]['text'] ?? "No sidequests generated.";
  }

  Future<String> _generateStory(List<String> completedQuests) async {
    if (completedQuests.isEmpty) {
      return "You haven't completed any quests yet!";
    }

    final questSummaries = completedQuests
        .map((q) {
          final parts = extractSidequestParts(q);
          return 'At ${parts['location']}, you ${parts['objective']?.toLowerCase() ?? 'completed a task'} ("${parts['title']}").';
        })
        .join('\n');

    final prompt =
        '''
You are a fantasy narrator. Write a short, immersive, in-universe story (in the style of a quest log or bard's tale) about the following completed quests, weaving them together as a single adventure for the day. Make it poetic, mysterious, and fun. Here are the quest summaries:

$questSummaries

Do not add anything outside the story.
''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$geminiApiKey',
    );

    final body = json.encode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    final data = json.decode(response.body);

    if (data == null ||
        data['candidates'] == null ||
        data['candidates'].isEmpty) {
      throw Exception(
        "Gemini API returned no content: ${data['error'] ?? 'Unknown error'}",
      );
    }

    final content = data['candidates'][0]['content'];
    if (content == null ||
        content['parts'] == null ||
        content['parts'].isEmpty) {
      throw Exception("Gemini content format is unexpected.");
    }

    return content['parts'][0]['text'] ?? "No story generated.";
  }

  void _fetchSidequests() async {
    try {
      setState(() => _sidequests = "Generating sidequests...");
      print("Getting current location...");
      final position = await _getLocation();
      print("Location: ${position.latitude}, ${position.longitude}");

      print("Fetching nearby places...");
      final places = await _getNearbyPlaces(position);
      print("Places: $places");

      // Shuffle the places to provide a varied experience each time
      places.shuffle();

      print("Generating sidequests...");
      final quests = await _generateSidequests(places);
      print("Quests: $quests");

      setState(() => _sidequests = quests);
    } catch (e) {
      print("Error: $e");
      setState(() => _sidequests = "Something went wrong: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final questList = _sidequests == 'Press the button to get quests!'
        ? []
        : _sidequests
              .split(RegExp(r'(?=Quest:)'))
              .where((q) => q.trim().isNotEmpty)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Marco Polo',
          style: TextStyle(
            fontSize: 28, // Make the title larger
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 242, 188, 135),
      ),
      backgroundColor: const Color.fromARGB(255, 242, 188, 135),
      body: _selectedTab == 0
          ? ListView(
              padding: const EdgeInsets.all(16.0),
              children: _sidequests == 'Press the button to get quests!'
                  ? [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 241, 213, 199),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            _sidequests,
                            style: const TextStyle(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ]
                  : questList.map((quest) {
                      final parts = extractSidequestParts(quest);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 241, 213, 199),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              parts['title']?.isNotEmpty == true
                                  ? parts['title']!
                                  : 'Sidequest',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (parts['location']!.isNotEmpty)
                              Text(
                                'Location: ${parts['location']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            if (parts['objective']!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Objective: ${parts['objective']}',
                                  style: const TextStyle(fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            if (parts['lore']!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Lore: ${parts['lore']}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.brown,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  74,
                                  149,
                                  86,
                                ), // Change this to any color you like
                                foregroundColor: Colors.white, // Text color
                              ),
                              onPressed: () {
                                setState(() {
                                  // Store completed quest
                                  _completedQuests.add(quest);
                                  // Remove this quest from the _sidequests string
                                  final updatedList = _sidequests
                                      .split(RegExp(r'(?=Quest:)'))
                                      .where(
                                        (q) =>
                                            q.trim().isNotEmpty && q != quest,
                                      )
                                      .toList();
                                  _sidequests = updatedList.isEmpty
                                      ? 'Press the button to get quests!'
                                      : updatedList.join('\n');
                                });
                              },
                              child: const Text('Complete'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
            )
          : _selectedTab == 1
          ? ListView(
              padding: const EdgeInsets.all(16.0),
              children: _completedQuests.isEmpty
                  ? [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 241, 213, 199),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'No completed quests yet!',
                            style: TextStyle(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ]
                  : _completedQuests.map((quest) {
                      final parts = extractSidequestParts(quest);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              parts['title']?.isNotEmpty == true
                                  ? parts['title']!
                                  : 'Sidequest',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (parts['location']!.isNotEmpty)
                              Text(
                                'Location: ${parts['location']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            if (parts['objective']!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Objective: ${parts['objective']}',
                                  style: const TextStyle(fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            if (parts['lore']!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Lore: ${parts['lore']}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.brown,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isGeneratingStory
                          ? null
                          : () async {
                              setState(() {
                                _isGeneratingStory = true;
                                _story = '';
                              });
                              try {
                                final story = await _generateStory(
                                  _completedQuests,
                                );
                                setState(() {
                                  _story = story;
                                });
                              } catch (e) {
                                setState(() {
                                  _story =
                                      "Something went wrong generating your story: $e";
                                });
                              } finally {
                                setState(() {
                                  _isGeneratingStory = false;
                                });
                              }
                            },
                      child: const Text('Generate My Adventure Story'),
                    ),
                    const SizedBox(height: 24),
                    if (_isGeneratingStory) const CircularProgressIndicator(),
                    if (_story.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 241, 213, 199),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _story,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        backgroundColor: Color.fromARGB(255, 242, 188, 135),
        onTap: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Sidequests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Completed',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Story'),
        ],
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              onPressed: _fetchSidequests,
              child: Icon(Icons.explore),
            )
          : null,
    );
  }
}
