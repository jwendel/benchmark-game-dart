import 'dart:io';
import 'dart:typeddata';

const String ALU =
"GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
"GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
"CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
"ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
"GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
"AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
"AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

final Frequency IUB = new Frequency(
    ['a',  'c',  'g',  't',
     'B',  'D',  'H',  'K',
     'M',  'N',  'R',  'S',
     'V',  'W',  'Y'],
     [0.27, 0.12, 0.12, 0.27,
      0.02, 0.02, 0.02, 0.02,
      0.02, 0.02, 0.02, 0.02,
      0.02, 0.02, 0.02,]);

final Frequency HOMO_SAPIENS = new Frequency(
     [ 'a',
       'c',
       'g',
       't'],
     [ 0.3029549426680,
       0.1979883004921,
       0.1975473066391,
       0.3015094502008]);

const int IM = 139968;
const int IA = 3877;
const int IC = 29573;

const int LINE_LENGTH = 60;
const int BUFFER_SIZE = (LINE_LENGTH + 1)*1024;

int last = 42;

double random(double max) {
  double oneOverIM = (1.0/ IM);
  last = (last * IA + IC) % IM;
  return max * last * oneOverIM;
}


class Frequency {
  Uint8List chars;
  Float64List probs;

  Frequency(List<String> charList, List<double> probList) {
    chars = new Uint8List(charList.length);
    for (int i=0; i < chars.length; i++) {
      chars[i] = charList[i].codeUnitAt(0);
    }
    
    probs = new Float64List(probList.length);
    for (int i=0; i < probList.length; i++) {
      probs[i] = probList[i];
    }
    
    makeCumulative();
  }

  void makeCumulative() {
    double cp = 0.0;
    for (int i = 0; i < probs.length; i++) {
      cp += probs[i];
      probs[i] = cp;
    }
  }

  int selectRandomIntoBuffer(Uint8List buffer, int bufferIndex, int nRandom) {
    final int len = probs.length;

    outer:
    for (int rIndex = 0; rIndex < nRandom; rIndex++) {
      double r = random(1.0);
      for (int i = 0; i < len; i++) {
        if (r < probs[i]) {
          buffer[bufferIndex++] = chars[i];
          continue outer;
        }
      }

      buffer[bufferIndex++] = chars[len-1];
    }

    return bufferIndex;
  }
}

makeRepeatFasta(String id, String desc, String alu, int nChars, IOSink writer) {
  stderr.write("Repeat Start  ${w.elapsedMilliseconds} ms\n");
  writer.write(">${id} ${desc}\n");

  int aluIndex = 0;
  List<int> aluCodes = alu.codeUnits;

  Uint8List buffer = new Uint8List(BUFFER_SIZE);

  int bufferIndex = 0;
  while (nChars > 0) {
    int chunkSize;
    if (nChars >= LINE_LENGTH) {
      chunkSize = LINE_LENGTH;
    } else {
      chunkSize = nChars;
    }

    if (bufferIndex == BUFFER_SIZE) {
      writer.writeBytes(new Uint8List.view(buffer.buffer, 0, bufferIndex));
//      writer.writeBytes(buffer);
//      buffer = new Uint8List(BUFFER_SIZE);
      bufferIndex = 0;
    }

    for (int i = 0; i < chunkSize; i++) {
      if (aluIndex == aluCodes.length) {
        aluIndex = 0;
      }

      buffer[bufferIndex++] = aluCodes[aluIndex++];
    }
    buffer[bufferIndex++] = 10;

    nChars -= chunkSize;
  }

  writer.writeBytes(new Uint8List.view(buffer.buffer, 0, bufferIndex));
  stderr.write("Repeat END  ${w.elapsedMilliseconds} ms\n");
}



void makeRandomFasta(String id, String desc, Frequency fpf, int nChars, IOSink writer) {
  stderr.write("Random START  ${w.elapsedMilliseconds} ms\n");
  writer.write(">${id} ${desc}\n");

  Uint8List buffer = new Uint8List(BUFFER_SIZE);

  int bufferIndex = 0;
  while (nChars > 0) {
    int chunkSize;
    if (nChars >= LINE_LENGTH) {
      chunkSize = LINE_LENGTH;
    } else {
      chunkSize = nChars;
    }

    if (bufferIndex == BUFFER_SIZE) {
      writer.writeBytes(new Uint8List.view(buffer.buffer, 0, bufferIndex));
//      writer.writeBytes(buffer);
//      buffer = new Uint8List(BUFFER_SIZE);
      bufferIndex = 0;
    }

    bufferIndex = fpf.selectRandomIntoBuffer(buffer, bufferIndex, chunkSize);
    buffer[bufferIndex++] = 10;

    nChars -= chunkSize;
  }

  writer.writeBytes(new Uint8List.view(buffer.buffer, 0, bufferIndex));
  stderr.write("Random END  ${w.elapsedMilliseconds} ms\n");

}

var w = new Stopwatch()..start();
main() {
  stderr.write("main start  ${w.elapsedMilliseconds} ms\n");
  
  var writer = stdout;

  int n = 250;
  List<String> args = new Options().arguments;
  if (args != null && args.length > 0) {
    n = int.parse(args[0]);
  }

  makeRepeatFasta("ONE", "Homo sapiens alu", ALU, n * 2, writer);
  makeRandomFasta("TWO", "IUB ambiguity codes", IUB, n * 3, writer);
  makeRandomFasta("THREE", "Homo sapiens frequency", HOMO_SAPIENS, n * 5, writer);

  stderr.write("END  ${w.elapsedMilliseconds} ms\n");

}