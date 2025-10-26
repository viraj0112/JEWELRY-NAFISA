import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Quote {
  final String text;
  final String author;

  Quote({required this.text, required this.author});

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      text: json['text'],
      author: json['author'],
    );
  }
}

class QuoteService {
  final String apiUrl = 'https://api.quotable.io/random';

  Future<Quote> fetchRandomQuote() async {
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Quote.fromJson(json);
    } else {
      throw Exception('Failed to load quote');
    }
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<Quote> futureQuote;

  @override
  void initState() {
    super.initState();
    futureQuote = QuoteService().fetchRandomQuote();
  }

  void _getNewQuote() {
    setState(() {
      futureQuote = QuoteService().fetchRandomQuote();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Random Quote Generator'),
      ),
      body: Center(
        child: FutureBuilder<Quote>(
          future: futureQuote,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              final quote = snapshot.data!;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '"${quote.text}"',
                    style: TextStyle(fontSize: 24, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '- ${quote.author}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _getNewQuote,
                    child: Text('Get Quote'),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    title: 'Quote Generator',
    home: MyHomePage(),
  ));
}
