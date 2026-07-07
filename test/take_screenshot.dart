import 'dart:io';
import 'package:puppeteer/puppeteer.dart';

void main() async {
  final sourceFile = File('c:\\MyDartProjects\\docx_rendering\\resources\\PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx');
  final targetFile = File('c:\\MyDartProjects\\docx_rendering\\test\\test.docx');
  
  if (await sourceFile.exists()) {
    print('Copying file to test.docx...');
    await sourceFile.copy(targetFile.path);
  } else {
    print('ERROR: Source file does not exist at ${sourceFile.path}');
  }

  print('Launching browser...');
  final browser = await puppeteer.launch(
    executablePath: 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  );
  final page = await browser.newPage();

  page.onConsole.listen((msg) {
    print('CONSOLE [${msg.type}]: ${msg.text}');
  });

  page.onError.listen((err) {
    print('PAGE ERROR: $err');
  });

  print('Navigating to http://127.0.0.1:8080 ...');
  await page.goto('http://127.0.0.1:8080');

  print('Waiting 5 seconds for Dart script to initialize...');
  await Future.delayed(Duration(seconds: 5));

  print('Uploading file...');
  final fileInput = await page.$('input[type="file"]');
  await fileInput.uploadFile([targetFile]);

  print('Checking and dispatching change event...');
  await page.evaluate('''() => {
    const input = document.getElementById('fileInput');
    console.log('JS: input.files length = ' + (input.files ? input.files.length : 'null'));
    if (input.files && input.files.length > 0) {
      console.log('JS: dispatching change event');
      input.dispatchEvent(new Event('change'));
    }
  }''');

  print('Waiting 10 seconds for render to complete...');
  await Future.delayed(Duration(seconds: 10));

  final info = await page.evaluate('''() => {
    const container = document.getElementById('container');
    const paras = Array.from(container.querySelectorAll('p')).map(p => ({
      text: p.textContent,
      className: p.className
    })).slice(0, 15);
    return {
      parasCount: Array.from(container.querySelectorAll('p')).length,
      paras: paras
    };
  }''');

  print('Paragraphs count: ${info['parasCount']}');
  print('Paragraphs list: ${info['paras']}');

  print('Taking screenshot...');
  final screenshotBytes = await page.screenshot(fullPage: false);

  final outputPath = 'C:\\Users\\pmro\\.gemini\\antigravity-ide\\brain\\3efd4d04-eb04-482e-9546-c4a5fb8376d9\\screenshot.png';
  print('Saving screenshot to $outputPath ...');
  await File(outputPath).writeAsBytes(screenshotBytes);

  await browser.close();
  print('Done!');
}
