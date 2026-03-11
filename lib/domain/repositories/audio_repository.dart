import 'package:fpdart/fpdart.dart';
import '../entities/song.dart';
import '../../core/error/failures.dart';

abstract class AudioRepository {
  Future<Either<Failure, List<Song>>> getSongs();
}
