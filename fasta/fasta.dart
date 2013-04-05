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

const double oneOverIM = (1.0/ IM);

const bool DEBUG = false;
Stopwatch w;

class Frequency {
  Uint16List chars;
  List<double> probs;
  int last;
  
  double random(double max) {
    last = (last * IA + IC) % IM;
    return max * last * oneOverIM;
  }

  Frequency(List<String> charList, List<double> probList) {
    chars = new Uint16List(charList.length);
    for (int i=0; i < chars.length; i++) {
      chars[i] = charList[i].codeUnitAt(0);
    }

    probs = new List<double>(probList.length);
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

  int selectRandomIntoBuffer(Uint16List buffer, int bufferIndex, int nRandom) {
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

makeRepeatFasta(String id, String desc, String alu, int _nChars, IOSink writer) {
  if (DEBUG) stderr.write("Repeat Start  ${w.elapsedMilliseconds} ms\n");
  writer.write(">${id} ${desc}\n");

  int aluIndex = 0;
  final List<int> aluCode = alu.codeUnits;
  final int aluLength = aluCode.length;

  Uint16List buffer = new Uint16List(BUFFER_SIZE);

  int bufferIndex = 0;
  int nChars = _nChars;
  while (nChars > 0) {
    final int chunkSize = nChars >= LINE_LENGTH ? LINE_LENGTH : nChars;

    if (bufferIndex == BUFFER_SIZE) {
      writer.writeBytes(new Uint16List.view(buffer.buffer, 0, bufferIndex));
      buffer = new Uint16List(BUFFER_SIZE);
      bufferIndex = 0;
    }

    if (aluIndex + chunkSize < aluLength) {
      buffer.setRange(bufferIndex, chunkSize, aluCode, aluIndex);
      bufferIndex += chunkSize;
      aluIndex += chunkSize;
    } else {
      int len = aluLength - aluIndex;
      buffer.setRange(bufferIndex, len, aluCode, aluIndex);
      bufferIndex += len;
      aluIndex = 0;
      len = chunkSize - len;
      buffer.setRange(bufferIndex, len, aluCode, aluIndex);
      bufferIndex += len;
      aluIndex += len;
    }

    buffer[bufferIndex++] = 10;

    nChars -= chunkSize;
  }

  writer.writeBytes(new Uint16List.view(buffer.buffer, 0, bufferIndex));
  if (DEBUG) stderr.write("Repeat END  ${w.elapsedMilliseconds} ms\n");
}



void makeRandomFasta(String id, String desc, Frequency fpf, int nChars, IOSink writer) {
  if (DEBUG) stderr.write("Random START  ${w.elapsedMilliseconds} ms\n");
  writer.write(">${id} ${desc}\n");

  Uint16List buffer = new Uint16List(BUFFER_SIZE);

  int bufferIndex = 0;
  while (nChars > 0) {
    final int chunkSize = nChars >= LINE_LENGTH ? LINE_LENGTH : nChars;

    if (bufferIndex == BUFFER_SIZE) {
      writer.writeBytes(new Uint16List.view(buffer.buffer, 0, bufferIndex));
      buffer = new Uint16List(BUFFER_SIZE);
      bufferIndex = 0;
    }

    bufferIndex = fpf.selectRandomIntoBuffer(buffer, bufferIndex, chunkSize);
    buffer[bufferIndex++] = 10;

    nChars -= chunkSize;
  }


  writer.writeBytes(new Uint16List.view(buffer.buffer, 0, bufferIndex));
  if (DEBUG) stderr.write("Random END  ${w.elapsedMilliseconds} ms\n");
}


main() {
  if (DEBUG) {
    w = new Stopwatch()..start();
    stderr.write("main start  ${w.elapsedMilliseconds} ms\n");
  }

//  IOSink writer = stdout;
  IOSink writer = new File(r'a.txt').openWrite();

  int n = 2500000;
  List<String> args = new Options().arguments;
  if (args != null && args.length > 0) {
    n = int.parse(args[0]);
  }

  makeRepeatFasta("ONE", "Homo sapiens alu", ALU, n * 2, writer);
  IUB.last = 42;
  makeRandomFasta("TWO", "IUB ambiguity codes", IUB, n * 3, writer);
  HOMO_SAPIENS.last = IUB.last;
  makeRandomFasta("THREE", "Homo sapiens frequency", HOMO_SAPIENS, n * 5, writer);

  if (DEBUG) {
    writer.done.then((_) => stderr.write("CLOSED  ${w.elapsedMilliseconds} ms\n"));
    writer.close();
    stderr.write("END  ${w.elapsedMilliseconds} ms\n");
  }
}

