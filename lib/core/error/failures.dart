abstract class Failure {
  final String message;
  const Failure(this.message);
}

class DeviceStorageFailure extends Failure {
  const DeviceStorageFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
