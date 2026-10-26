import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _OpenC = Int32 Function(Pointer<Utf8> path, Int32 flags);
typedef _OpenDart = int Function(Pointer<Utf8> path, int flags);
typedef _FdC = Int32 Function(Int32 fd);
typedef _FdDart = int Function(int fd);
typedef _Dup2C = Int32 Function(Int32 from, Int32 to);
typedef _Dup2Dart = int Function(int from, int to);
typedef _WriteC = IntPtr Function(Int32 fd, Pointer<Uint8> buf, IntPtr count);
typedef _WriteDart = int Function(int fd, Pointer<Uint8> buf, int count);

const _stderrFd = 2;

/// O_WRONLY, the same on Darwin, Linux and Android. Without O_CREAT `open`
/// takes no variadic mode argument, which FFI can't pass portably.
const _oWronly = 1;

/// Sends the process's stderr (fd 2) to a file while it is active.
///
/// llama.cpp and mtmd write their log, `image slice encoded in N ms` among
/// it, to stderr; llamadart never forwards it to the Dart log handler. A
/// file rather than a pipe, so a slow reader can never block native writes.
/// [drain] returns what was written since the last call and passes it on to
/// the original stderr, so the console still shows it.
class NativeLogCapture {
  NativeLogCapture._(this._file, this._savedFd, this._dup2, this._close, this._write);

  final File _file;
  final int _savedFd;
  final _Dup2Dart _dup2;
  final _FdDart _close;
  final _WriteDart _write;
  var _offset = 0;
  var _active = true;

  /// Redirects stderr to [path] (created or truncated). Throws when a libc
  /// call fails, leaving stderr as it was.
  static NativeLogCapture start(String path) {
    final libc = DynamicLibrary.process();
    final open = libc.lookupFunction<_OpenC, _OpenDart>('open');
    final dup = libc.lookupFunction<_FdC, _FdDart>('dup');
    final dup2 = libc.lookupFunction<_Dup2C, _Dup2Dart>('dup2');
    final close = libc.lookupFunction<_FdC, _FdDart>('close');
    final write = libc.lookupFunction<_WriteC, _WriteDart>('write');

    final file = File(path)..writeAsBytesSync(const [], flush: true);
    final cPath = path.toNativeUtf8();
    final fd = open(cPath, _oWronly);
    malloc.free(cPath);
    if (fd < 0) throw StateError('open($path) failed');
    final saved = dup(_stderrFd);
    if (saved < 0) {
      close(fd);
      throw StateError('dup(stderr) failed');
    }
    if (dup2(fd, _stderrFd) < 0) {
      close(fd);
      close(saved);
      throw StateError('dup2(stderr) failed');
    }
    close(fd);
    return NativeLogCapture._(file, saved, dup2, close, write);
  }

  /// Text written to stderr since the last call, also copied to the
  /// original stderr. Empty once [stop] has run.
  String drain() {
    if (!_active) return '';
    final raf = _file.openSync();
    final List<int> bytes;
    try {
      final end = raf.lengthSync();
      if (end <= _offset) return '';
      raf.setPositionSync(_offset);
      bytes = raf.readSync(end - _offset);
    } finally {
      raf.closeSync();
    }
    _offset += bytes.length;
    _forward(bytes);
    return utf8.decode(bytes, allowMalformed: true);
  }

  void _forward(List<int> bytes) {
    final buf = malloc<Uint8>(bytes.length);
    try {
      buf.asTypedList(bytes.length).setAll(0, bytes);
      var done = 0;
      while (done < bytes.length) {
        final n = _write(_savedFd, buf + done, bytes.length - done);
        if (n <= 0) break;
        done += n;
      }
    } finally {
      malloc.free(buf);
    }
  }

  /// Drains and restores the original stderr. The file is kept: it is the
  /// run's full native log.
  void stop() {
    if (!_active) return;
    drain();
    _active = false;
    _dup2(_savedFd, _stderrFd);
    _close(_savedFd);
  }
}
