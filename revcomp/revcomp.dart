import 'dart:io';
import 'dart:typeddata';

void main() {
  String src   = "CGATMKRYVBHD";
  String dst   = "GCTAKMYRBVDH";
  Uint8List tbl   = new Uint8List(256);

  // Set up lookup table
  for (int i = 0; i < tbl.length; i++)
    tbl[i] = i;

  for (int i = 0; i < src.length; i++) {
    tbl[src.codeUnitAt(i)]                = dst.codeUnitAt(i);
    tbl[src.toLowerCase().codeUnitAt(i)]  = dst.codeUnitAt(i);
  }

  const int BUFFER_SIZE = 1024*1024;
  Uint8List buffer = new Uint8List(60);
  List<int> list = new List<int>();
  bool commentLine = false;
  Uint8List sbuf = new Uint8List(BUFFER_SIZE);
  int pos = 0;



  void copyAndPrint(List<int> src, int size) {
    int start = 0;
    if (size + pos > BUFFER_SIZE) {
      while (pos < BUFFER_SIZE) {
        sbuf[pos++] = src[start++];
      }
      stdout.writeBytes(sbuf);
      sbuf = new Uint8List(BUFFER_SIZE);
      pos = 0;
    }

    for (int i=start; i < size;i++) {
      sbuf[pos++] = src[i];
    }
  }

  void addNewline() {
    if (pos == BUFFER_SIZE) {
      stdout.writeBytes(sbuf);
      sbuf = new Uint8List(BUFFER_SIZE);
      pos = 0;
    }

    sbuf[pos++] = 10;
  }

  stdin.listen((List<int> dataList) {
    // Loop over all the contents of the buffer so far
    for (int data in dataList) {

      // Check if this is a comment line (and that we aren't already on a comment line)
      if (data == 62 && !commentLine) {
        int count = 0;

        // Print the reverse components for the last block
        for (int g in list.reversed) {
          if (count == 60) {

            copyAndPrint(buffer, count);
            addNewline();
            count=0;
          }
          buffer[count++] = g;
        }
        // Print any stragling data
        if (count > 0) {
          copyAndPrint(buffer, count);
          addNewline();
        }
        // Reset the data for the begining of a block of data
        list.clear();
        commentLine = true;
      }

      if (commentLine) {
        if (data == 10) {
          copyAndPrint(list, list.length);
          addNewline();
          commentLine = false;
          list.clear();
        } else {
          list.add(data);
        }
      } else if (data != 10) {
          // Add the complement to the buffer
          list.add(tbl[data]);
      }
    }
  }).onDone(() {
    // Print out anything remaining in the buffers
    if (commentLine) {
      copyAndPrint(list, list.length);
      addNewline();
    } else {
      int count = 0;
      for (int data in list.reversed) {
        if (count == 60) {
          copyAndPrint(buffer, count);
          addNewline();
          count=0;
        }
        buffer[count++] = data;
      }
      if (count > 0) {
        copyAndPrint(buffer, count);
        addNewline();
      }
    }
    if (pos > 0)
      stdout.writeBytes(sbuf.sublist(0, pos));
  });
}
