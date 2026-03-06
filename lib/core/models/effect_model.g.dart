// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'effect_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EffectTypeAdapter extends TypeAdapter<EffectType> {
  @override
  final int typeId = 2;

  @override
  EffectType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return EffectType.dreamyGlow;
      case 1:
        return EffectType.filmGrain;
      case 2:
        return EffectType.dustTexture;
      case 3:
        return EffectType.lightLeak;
      case 4:
        return EffectType.dateStamp;
      default:
        return EffectType.dreamyGlow;
    }
  }

  @override
  void write(BinaryWriter writer, EffectType obj) {
    switch (obj) {
      case EffectType.dreamyGlow:
        writer.writeByte(0);
        break;
      case EffectType.filmGrain:
        writer.writeByte(1);
        break;
      case EffectType.dustTexture:
        writer.writeByte(2);
        break;
      case EffectType.lightLeak:
        writer.writeByte(3);
        break;
      case EffectType.dateStamp:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EffectTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
