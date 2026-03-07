// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserPreferencesAdapter extends TypeAdapter<UserPreferences> {
  @override
  final int typeId = 3;

  @override
  UserPreferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserPreferences(
      hasSeenOnboarding: fields[0] as bool? ?? false,
      lastUsedFilterId: fields[1] as String?,
      isProUser: fields[2] as bool? ?? false,
      filterIntensities: (fields[3] as Map?)?.cast<String, double>(),
      favoriteFilterIds: (fields[4] as List?)?.cast<String>(),
      hasSeenDreamyGlowTip: fields[5] as bool? ?? false,
      hasSeenSwipeHint: fields[6] as bool? ?? false,
      hasSeenEditHint: fields[7] as bool? ?? false,
      totalPhotosCapture: fields[8] as int? ?? 0,
      isSilentShutter: fields[9] as bool? ?? false,
      isLivePhotoEnabled: fields[10] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, UserPreferences obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.hasSeenOnboarding)
      ..writeByte(1)
      ..write(obj.lastUsedFilterId)
      ..writeByte(2)
      ..write(obj.isProUser)
      ..writeByte(3)
      ..write(obj.filterIntensities)
      ..writeByte(4)
      ..write(obj.favoriteFilterIds)
      ..writeByte(5)
      ..write(obj.hasSeenDreamyGlowTip)
      ..writeByte(6)
      ..write(obj.hasSeenSwipeHint)
      ..writeByte(7)
      ..write(obj.hasSeenEditHint)
      ..writeByte(8)
      ..write(obj.totalPhotosCapture)
      ..writeByte(9)
      ..write(obj.isSilentShutter)
      ..writeByte(10)
      ..write(obj.isLivePhotoEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferencesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
