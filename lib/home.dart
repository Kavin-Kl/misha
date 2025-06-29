import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SongDetails {
  final String name;
  final String spotifyTrackId;
  final String? spotifyArtistId;
  double? tempo;
  double? valence;
  double? danceability;
  List<String>? genres;

  SongDetails({
    required this.name,
    required this.spotifyTrackId,
    this.spotifyArtistId,
    this.tempo,
    this.valence,
    this.danceability,
    this.genres,
  });

  String get valenceDescription {
    if (valence == null) return 'unknown mood';
    if (valence! >= 0.75) return 'very positive and uplifting';
    if (valence! >= 0.5) return 'positive';
    if (valence! >= 0.25) return 'neutral to slightly melancholic';
    return 'somber and melancholic';
  }

  String get danceabilityDescription {
    if (danceability == null) return 'unknown danceability';
    if (danceability! >= 0.7) return 'very high - suitable for dancing';
    if (danceability! >= 0.5) return 'moderate';
    if (danceability! >= 0.3) return 'low - not very danceable';
    return 'very low - not for dancing';
  }

  String get tempoString {
    if (tempo == null) return 'unknown tempo';
    return '${tempo!.round()} BPM';
  }

  String get genreString {
    if (genres == null || genres!.isEmpty) return 'unknown genre';
    final cleanedGenres = genres!
        .map((g) => g.replaceAll('-', ' '))
        .toSet()
        .join(', ');
    return cleanedGenres.isNotEmpty ? cleanedGenres : 'unknown genre';
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  static const String _spotifyClientId = 'f011bf39b38f4d85a09767458845e190';
  static const String _spotifyClientSecret = 'd107db753cc04ff1ac5319c54addcf2d';

  static const String _spotifyTokenUrl =
      'https://accounts.spotify.com/api/token';
  static const String _spotifySearchBaseUrl =
      'https://api.spotify.com/v1/search';
  static const String _spotifyAudioFeaturesBaseUrl =
      'https://api.spotify.com/v1/audio-features/';
  static const String _spotifyArtistsBaseUrl =
      'https://api.spotify.com/v1/artists/';

  Future<String> getSpotifyToken() async {
    if (_spotifyClientId == 'YOUR_SPOTIFY_CLIENT_ID' ||
        _spotifyClientSecret == 'YOUR_SPOTIFY_CLIENT_SECRET') {
      throw Exception(
        "Spotify API Client ID or Client Secret is not set. Please replace placeholders in home.dart.",
      );
    }
    final credentials = base64.encode(
      utf8.encode('$_spotifyClientId:$_spotifyClientSecret'),
    );

    try {
      final response = await http.post(
        Uri.parse(_spotifyTokenUrl),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      } else {
        throw Exception(
          'Failed to get Spotify token: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> fetchSongSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      final token = await getSpotifyToken();
      final searchUri = Uri.parse(
        '$_spotifySearchBaseUrl?q=${Uri.encodeComponent(query)}&type=track&limit=5',
      );

      final response = await http.get(
        searchUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = data['tracks']?['items'] ?? [];
        return List<String>.from(
          tracks.map((track) => track['name'] ?? 'Unknown Song'),
        );
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<SongDetails?> _getSongDetails(String songName) async {
    if (songName.isEmpty) return null;

    try {
      final token = await getSpotifyToken();

      final searchUrl = Uri.parse(
        '$_spotifySearchBaseUrl?q=${Uri.encodeComponent(songName)}&type=track&limit=1',
      );
      final searchResponse = await http.get(
        searchUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (searchResponse.statusCode != 200) {
        throw Exception(
          "Spotify Search Error: ${searchResponse.statusCode} - ${searchResponse.body}",
        );
      }

      final searchData = jsonDecode(searchResponse.body);
      final tracks = searchData['tracks']?['items'];
      if (tracks == null || tracks.isEmpty) {
        return null;
      }

      final track = tracks[0];
      final trackId = track['id'] as String;
      final artistId = (track['artists'] as List).isNotEmpty
          ? track['artists'][0]['id'] as String
          : null;
      final fullSongName = track['name'] as String;

      SongDetails songDetails = SongDetails(
        name: fullSongName,
        spotifyTrackId: trackId,
        spotifyArtistId: artistId,
      );

      final audioFeaturesUrl = Uri.parse(
        '$_spotifyAudioFeaturesBaseUrl$trackId',
      );
      final audioFeaturesResponse = await http.get(
        audioFeaturesUrl,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (audioFeaturesResponse.statusCode == 200) {
        final audioFeaturesData = jsonDecode(audioFeaturesResponse.body);
        songDetails.tempo = audioFeaturesData['tempo']?.toDouble();
        songDetails.valence = audioFeaturesData['valence']?.toDouble();
        songDetails.danceability = audioFeaturesData['danceability']
            ?.toDouble();
      } else {}

      if (artistId != null) {
        final artistUrl = Uri.parse('$_spotifyArtistsBaseUrl$artistId');
        final artistResponse = await http.get(
          artistUrl,
          headers: {'Authorization': 'Bearer $token'},
        );

        if (artistResponse.statusCode == 200) {
          final artistData = jsonDecode(artistResponse.body);
          songDetails.genres = (artistData['genres'] as List?)
              ?.map((g) => g.toString())
              .toList();
        } else {}
      }
      return songDetails;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchMoviesAndNavigate(String songName) async {
    setState(() => _isLoading = true);
    try {
      final songDetails = await _getSongDetails(songName);

      if (songDetails == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Could not retrieve song details from Spotify. Please try another song or check your Spotify API keys.",
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final movies = await queryGeminiForMovies(songDetails);

      if (!mounted) return;

      if (movies.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No movies found for this song.")),
        );
        setState(() => _isLoading = false);
        return;
      }

      Navigator.pushNamed(context, '/display', arguments: {'movies': movies});
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      return;
    }
    setState(() => _isLoading = false);
  }

  static const String _tmdbApiKey = 'ccd7139859c7a44a0218e943cf28e248';
  static const String _tmdbApiBaseUrl = 'api.themoviedb.org';
  static const String _tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  Future<String?> _fetchPosterUrlFromTMDbSearch(
    String movieTitleWithYear,
  ) async {
    if (_tmdbApiKey == 'YOUR_TMDB_API_KEY' || _tmdbApiKey.isEmpty) {
      return null;
    }

    String title = movieTitleWithYear;
    String? year;
    RegExp yearRegExp = RegExp(r'\((\d{4})\)');
    Match? match = yearRegExp.firstMatch(movieTitleWithYear);

    if (match != null && match.groupCount >= 1) {
      year = match.group(1);
      title = movieTitleWithYear.replaceAll(yearRegExp, '').trim();
    }

    final queryParameters = {
      'api_key': _tmdbApiKey,
      'query': title,
      if (year != null) 'year': year,
    };

    final uri = Uri.https(_tmdbApiBaseUrl, '/3/search/movie', queryParameters);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>?;

        if (results != null && results.isNotEmpty) {
          final posterPath = results[0]['poster_path'] as String?;
          if (posterPath != null && posterPath.isNotEmpty) {
            return '$_tmdbImageBaseUrl$posterPath';
          }
        }
      }
    } catch (e) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> queryGeminiForMovies(
    SongDetails songDetails,
  ) async {
    const geminiApiKey = 'AIzaSyAAfv80KMOA3q33afStzyEF64TLXDcvA6E';

    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: geminiApiKey,
    );

    final prompt =
        '''
You are a movie expert with deep knowledge of emotional storytelling, genres, and audience mood alignment.

I have a song with the following characteristics:
- Title: "${songDetails.name}"
- Tempo: ${songDetails.tempoString}
- Mood (Valence): ${songDetails.valenceDescription}
- Danceability: ${songDetails.danceabilityDescription}
- Main Genre: ${songDetails.genreString}

Your task is to suggest **exactly 5 real, existing movies** that emotionally and tonally align with the **feel of this song** based on the above characteristics.

Each movie should match the song’s **energy, pacing, mood, and genre influence**. For example:
- A high-tempo, happy, danceable pop song → a feel-good musical, romantic comedy, or vibrant teen drama.
- A slow, melancholic, low-danceability piece → a contemplative drama, indie romance, or tragic character study.

⚠️ Return only a clean JSON array with **full movie titles (including release year)** and optionally their **IMDb IDs**.

📦 Format: (Strict)
[
  {"title": "Movie Title (Release Year)", "imdb_id": "tt1234567"},
  ...
]

✅ Rules:
- Titles must be **real, released films**. No made-up movies.
- Titles must include **release year** in this exact format: `Movie Title (YYYY)`
- `imdb_id` is optional but should start with `"tt"` and be accurate if included.
- ❌ Do NOT include any explanation, commentary, or markdown.
- ❌ Do NOT add any extra characters before or after the JSON array.
- ❌ Do NOT say “Here is your result” or wrap in triple backticks.

🎯 Goal:
Make this list feel like a **perfect cinematic echo** of the song. Prioritize emotional, tonal, and thematic resonance.

Example output:
[
  {"title": "La La Land (2016)", "imdb_id": "tt3783958"},
  {"title": "Begin Again (2013)", "imdb_id": "tt1980929"},
  {"title": "Call Me by Your Name (2017)", "imdb_id": "tt5726616"},
  {"title": "The Perks of Being a Wallflower (2012)", "imdb_id": "tt1659337"},
  {"title": "Inside Llewyn Davis (2013)", "imdb_id": "tt2042568"}
]
''';

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final rawText = response.text;

      if (rawText == null || rawText.isEmpty) {
        throw Exception("Empty or invalid response from Gemini.");
      }

      dynamic parsedJson;
      try {
        parsedJson = jsonDecode(rawText);
      } catch (e) {
        String cleanedText = rawText
            .trim()
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final startIndex = cleanedText.indexOf('[');
        final endIndex = cleanedText.lastIndexOf(']');

        if (startIndex == -1 || endIndex == -1) {
          throw Exception(
            'Could not locate JSON array in response after cleanup. Raw text: $cleanedText',
          );
        }

        final jsonStr = cleanedText.substring(startIndex, endIndex + 1);
        try {
          parsedJson = jsonDecode(jsonStr);
        } catch (innerE) {
          throw Exception(
            "Gemini returned invalid JSON format even after extraction and cleanup. Extracted: $jsonStr",
          );
        }
      }

      if (parsedJson is List) {
        List<Map<String, dynamic>> processedMovies = [];
        for (var item in parsedJson) {
          if (item is Map<String, dynamic>) {
            final titleWithYear = item['title'] as String?;

            if (titleWithYear != null) {
              String? posterUrl = await _fetchPosterUrlFromTMDbSearch(
                titleWithYear,
              );

              processedMovies.add({
                "title": titleWithYear,
                "poster_url": posterUrl ?? _getGenericDummyPosterUrl(),
              });
            } else {}
          } else {}
        }

        if (processedMovies.isEmpty) {
          return _getDummyMovies(
            error:
                "No valid movies from Gemini or poster fetching failed for all.",
          );
        }
        return processedMovies;
      } else {
        throw Exception("Gemini returned JSON is not a list.");
      }
    } on GenerativeAIException catch (e) {
      return _getDummyMovies(error: "Gemini API Error (SDK): ${e.message}");
    } catch (e) {
      return _getDummyMovies(error: "Gemini API Exception: $e");
    }
  }

  String _getGenericDummyPosterUrl() {
    return "https://via.placeholder.com/150x225?text=No+Poster";
  }

  List<Map<String, dynamic>> _getDummyMovies({String error = ""}) {
    return [
      {
        "title": "Fallback Movie 1",
        "poster_url":
            "https://via.placeholder.com/150x225?text=Fallback+Poster+1",
      },
      {
        "title": "Fallback Movie 2",
        "poster_url":
            "https://via.placeholder.com/150x225?text=Fallback+Poster+2",
      },
      {
        "title": "Fallback Movie 3",
        "poster_url":
            "https://via.placeholder.com/150x225?text=Fallback+Poster+3",
      },
      {
        "title": "Fallback Movie 4",
        "poster_url":
            "https://via.placeholder.com/150x225?text=Fallback+Poster+4",
      },
      {
        "title": "Fallback Movie 5",
        "poster_url":
            "https://via.placeholder.com/150x225?text=Fallback+Poster+5",
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '<Misha>',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      return await fetchSongSuggestions(textEditingValue.text);
                    },
                    fieldViewBuilder:
                        (
                          context,
                          textEditingController,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          _controller.value = textEditingController.value;
                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter a song name...',
                              hintStyle: const TextStyle(
                                color: Color(0xFFB0BEC5),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF232323),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
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
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                            onSubmitted: (value) {
                              final song = textEditingController.text.trim();
                              if (song.isNotEmpty) {
                                fetchMoviesAndNavigate(song);
                              }
                            },
                          );
                        },
                    onSelected: (String selection) {
                      _controller.text = selection;
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: const Color(0xFF232323),
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 350,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(
                                    option,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  onTap: () {
                                    onSelected(option);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _isLoading
                      ? LoadingAnimationWidget.staggeredDotsWave(
                          color: Colors.white,
                          size: 32,
                        )
                      : ElevatedButton(
                          onPressed: () {
                            final song = _controller.text.trim();
                            if (song.isNotEmpty) {
                              fetchMoviesAndNavigate(song);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF232323),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Search'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
