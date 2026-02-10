import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Usamos un tema tipo "Papel" para mejorar la lectura
        scaffoldBackgroundColor: const Color(0xFFFDFBF7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFDFBF7),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const NewsFeedScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// PANTALLA 1: Feed de Google News (Igual que antes, fuente rápida)
// ---------------------------------------------------------------------------

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  List<Map<String, String>> _news = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGoogleNews();
  }

  Future<void> _fetchGoogleNews() async {
    // URL RSS Google News México/Latam
    final url = Uri.parse(
      'https://news.google.com/rss?hl=es-419&gl=MX&ceid=MX:es-419',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<Map<String, String>> loadedNews = [];
        for (var item in items) {
          loadedNews.add({
            'title': item.findElements('title').single.innerText,
            'link': item.findElements('link').single.innerText,
            'source': item.findElements('source').isNotEmpty
                ? item.findElements('source').single.innerText
                : 'Noticia',
          });
        }
        setState(() {
          _news = loadedNews;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Titulares")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _news.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  elevation: 0,
                  color: Colors.white,
                  child: ListTile(
                    title: Text(
                      _news[index]['title']!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _news[index]['source']!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ReaderModeScreen(url: _news[index]['link']!),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// PANTALLA 2: Lector Modo Lectura (Sin Anuncios, Sin Video)
// ---------------------------------------------------------------------------

class ReaderModeScreen extends StatefulWidget {
  final String url;
  const ReaderModeScreen({super.key, required this.url});

  @override
  State<ReaderModeScreen> createState() => _ReaderModeScreenState();
}

class _ReaderModeScreenState extends State<ReaderModeScreen> {
  InAppWebViewController? webViewController;
  bool isReadingModeActive = false;
  double progress = 0;

  // ESTE ES EL MOTOR DEL MODO LECTURA
  // Inyectamos esto para reconstruir la página completamente
  final String _readerModeScript = """
    (function() {
      // 1. Extraer el Título
      var title = document.querySelector('h1') ? document.querySelector('h1').innerText : document.title;
      
      // 2. Intentar encontrar la imagen principal (Meta tag og:image o primera imagen grande)
      var mainImg = "";
      var metaImg = document.querySelector('meta[property="og:image"]');
      if(metaImg) mainImg = '<img src="' + metaImg.content + '" style="width:100%; border-radius:10px; margin-bottom:20px;">';

      // 3. Extraer solo los PÁRRAFOS sustanciales
      // Buscamos contenedores de texto comunes en noticias
      var contentNodes = document.querySelectorAll('p, h2, h3, ul, blockquote');
      var extractedHTML = "";
      
      contentNodes.forEach(function(node) {
         // Filtros anti-basura:
         // Ignorar párrafos muy cortos (suelen ser fechas, autor, 'leé también')
         // Ignorar si tiene clases de anuncios
         var text = node.innerText;
         var className = node.className.toLowerCase();
         var idName = node.id.toLowerCase();
         
         if (text.length > 40 && 
             !className.includes('copyright') && 
             !className.includes('menu') &&
             !className.includes('ad') &&
             !idName.includes('footer')) {
             
             // Limpiar estilos inline para que nuestro CSS mande
             node.removeAttribute('style');
             node.removeAttribute('class');
             extractedHTML += node.outerHTML;
         }
      });

      if(extractedHTML.length < 100) {
        // Fallback si no encontramos nada (ej. sitios muy raros)
        extractedHTML = "<p>No pudimos extraer el texto automáticamente. Toca 'Ver Original' para recargar.</p>";
      }

      // 4. ELIMINAR TODO y REEMPLAZAR con nuestra plantilla limpia
      document.head.innerHTML = `
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
        <style>
          body { 
            font-family: 'Georgia', serif; 
            font-size: 19px; 
            line-height: 1.6; 
            color: #222; 
            background: #FDFBF7; 
            padding: 20px; 
            max-width: 800px; 
            margin: 0 auto;
          }
          h1 { font-family: 'Arial', sans-serif; font-size: 26px; line-height: 1.3; margin-bottom: 10px; }
          h2 { font-size: 22px; margin-top: 30px; }
          p { margin-bottom: 20px; }
          img { max-width: 100%; height: auto; display: block; margin: 20px 0; }
          blockquote { border-left: 4px solid #ccc; padding-left: 15px; font-style: italic; color: #555; }
          a { color: #0066cc; text-decoration: none; border-bottom: 1px dotted #0066cc; }
        </style>
      `;

      document.body.innerHTML = `
        <h1>` + title + `</h1>
        ` + mainImg + `
        <div id="clean-content">` + extractedHTML + `</div>
        <br><br><br>
        <p style="text-align:center; color:#999; font-size:14px;">Generado por Modo Lectura</p>
      `;
    })();
  """;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Botón flotante para alternar entre "Sitio Real" y "Lectura Limpia"
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black87,
        label: Text(isReadingModeActive ? "Ver Web Original" : "Limpiar Vista"),
        icon: Icon(isReadingModeActive ? Icons.web : Icons.chrome_reader_mode),
        onPressed: () {
          if (isReadingModeActive) {
            webViewController?.reload(); // Recarga normal
            setState(() => isReadingModeActive = false);
          } else {
            // Ejecutar limpieza manual
            webViewController?.evaluateJavascript(source: _readerModeScript);
            setState(() => isReadingModeActive = true);
          }
        },
      ),
      appBar: AppBar(
        title: const Text("Lector"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              mediaPlaybackRequiresUserGesture: true,
              // Bloqueamos popups automáticos
              javaScriptCanOpenWindowsAutomatically: false,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              // AUTOMATIZACIÓN:
              // En cuanto carga la página, intentamos limpiarla automáticamente
              // Si prefieres que el usuario decida, comenta la siguiente línea.
              await Future.delayed(
                const Duration(milliseconds: 800),
              ); // Esperar rendering inicial
              await controller.evaluateJavascript(source: _readerModeScript);
              setState(() => isReadingModeActive = true);
            },
            onProgressChanged: (controller, p) {
              setState(() => progress = p / 100);
            },
          ),
          if (progress < 1.0)
            LinearProgressIndicator(value: progress, color: Colors.black87),
        ],
      ),
    );
  }
}
