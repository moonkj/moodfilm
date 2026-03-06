// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FilterModelAdapter extends TypeAdapter<FilterModel> {
  @override
  final int typeId = 1;

  @override
  FilterModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FilterModel(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as FilterCategory,
      lutFileName: fields[3] as String,
      isPro: fields[4] as bool,
      isFavorite: fields[5] as bool,
      lastIntensity: fields[6] as double,
      packId: fields[7] as String?,
      isNew: fields[8] as bool,
      description: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FilterModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.lutFileName)
      ..writeByte(4)
      ..write(obj.isPro)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.lastIntensity)
      ..writeByte(7)
      ..write(obj.packId)
      ..writeByte(8)
      ..write(obj.isNew)
      ..writeByte(9)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FilterCategoryAdapter extends TypeAdapter<FilterCategory> {
  @override
  final int typeId = 0;

  @override
  FilterCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FilterCategory.warm;
      case 1:
        return FilterCategory.cool;
      case 2:
        return FilterCategory.film;
      case 3:
        return FilterCategory.aesthetic;
      default:
        return FilterCategory.warm;
    }
  }

  @override
  void write(BinaryWriter writer, FilterCategory obj) {
    switch (obj) {
      case FilterCategory.warm:
        writer.writeByte(0);
        break;
      case FilterCategory.cool:
        writer.writeByte(1);
        break;
      case FilterCategory.film:
        writer.writeByte(2);
        break;
      case FilterCategory.aesthetic:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
