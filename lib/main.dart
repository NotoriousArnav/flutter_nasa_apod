import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart'; // for LogicalKeyboardKey

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const String title = 'NASA Random APOD';
    const Color seedColor = Colors.yellow;
    ThemeData theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
    );
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme light = lightDynamic ?? ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        );
        final ColorScheme dark = darkDynamic ?? ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        );

        return MaterialApp(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: theme.copyWith(
            colorScheme: light,
            useMaterial3: true,
            textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Roboto'),
            scaffoldBackgroundColor: light.background, // *important*
          ),
          darkTheme: theme.copyWith(
            colorScheme: dark,
            useMaterial3: true,
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
            scaffoldBackgroundColor: dark.background,
          ),
          home: MyHomePage(title: title),
        );
      }
      ); 
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  String _hdurl = "";
  String _url = "";
  Apod? _apod = null;

  Future<Apod> fetchAPOD() async {
    final response = await http.get(Uri.parse('https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY&count=1'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => Apod.fromJson(item)).toList()[0];
      } else if (data is Map<String, dynamic>) {
        return Apod.fromJson(data);
      } else {
        // Handle unexpected data format
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Unexpected data format received from APOD API."),
        ));
        throw Exception('Unexpected data format');
      }
    } else {
      // Toast an error message if the request fails Indicating towards the user's netowk connectivity
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Failed to load APOD. Please check your network connection."),
      ));
      throw Exception("Failed to load APOD\nStatus Code: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hdurl.isEmpty) {
      fetchAPOD().then((value) {
        setState(() {
          _hdurl = value.hdUrl ?? value.url;
          _url = value.url;
          _apod = value;
        });
      });
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final int version = DateTime.now().millisecondsSinceEpoch;

    
    return CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
        fetchAPOD().then((value) {
          setState(() {
            _hdurl = value.hdUrl ?? value.url;
            _apod = value;
          });
        });
      },
    },
    /*Focus*/ 
    child: Focus(
      autofocus: true,
      child: Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: AspectRatio(
                aspectRatio: 4/3,
                child: Image.network(
                _hdurl.isNotEmpty ? _hdurl : _url,
                fit: BoxFit.fill,
                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Text('Failed to load image'));
                },
              )
              )
            ),
            const SizedBox(height: 20),
            Text(
              _apod?.title ?? 'Loading...',
              textAlign: TextAlign.center,
              style: textTheme.displayMedium,

            ),
            const SizedBox(height: 10),
            Text(
              '${_apod?.date ?? "Loading date..."}\t${_apod?.copyright ?? ""}',
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _apod?.explanation ?? 'Loading explanation...',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge
            ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          fetchAPOD()
            .then((value) {
              setState(() {
                _hdurl = value.hdUrl ?? value.url;
                _apod = value;
              });
            });
        },
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    )
    ),
    // Focus ends here
    );
  }
}


class Apod {
  final String date;
  final String title;
  final String explanation;
  final String url;
  final String? hdUrl;
  final String mediaType;
  final String? copyright;

  Apod({
    required this.date,
    required this.title,
    required this.explanation,
    required this.url,
    this.hdUrl,
    required this.mediaType,
    this.copyright,
  });

  factory Apod.fromJson(Map<String, dynamic> json) => Apod(
        date: json['date'] as String,
        title: json['title'] as String,
        explanation: json['explanation'] as String,
        url: json['url'] as String,
        hdUrl: json['hdurl'] as String?,
        mediaType: json['media_type'] as String,
        copyright: json['copyright'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'title': title,
        'explanation': explanation,
        'url': url,
        if (hdUrl != null) 'hdurl': hdUrl,
        'media_type': mediaType,
        if (copyright != null) 'copyright': copyright,
      };
}
