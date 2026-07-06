import '../document/paragraph.dart';
import '../document/run.dart';
import '../parser/xml_parser.dart';

/// Properties of the numbering part.
class NumberingPartProperties {
  List<Numbering> numberings;
  List<AbstractNumbering> abstractNumberings;
  List<NumberingBulletPicture> bulletPictures;

  NumberingPartProperties({
    List<Numbering>? numberings,
    List<AbstractNumbering>? abstractNumberings,
    List<NumberingBulletPicture>? bulletPictures,
  })  : numberings = numberings ?? [],
        abstractNumberings = abstractNumberings ?? [],
        bulletPictures = bulletPictures ?? [];
}

/// A concrete numbering definition.
class Numbering {
  String? id;
  String? abstractId;
  List<NumberingLevelOverride> overrides;

  Numbering({this.id, this.abstractId, List<NumberingLevelOverride>? overrides})
      : overrides = overrides ?? [];
}

/// Override for a numbering level.
class NumberingLevelOverride {
  int? level;
  int? start;
  NumberingLevel? numberingLevel;

  NumberingLevelOverride({this.level, this.start, this.numberingLevel});
}

/// Abstract numbering definition.
class AbstractNumbering {
  String? id;
  String? name;
  String? multiLevelType;
  List<NumberingLevel> levels;
  String? numberingStyleLink;
  String? styleLink;

  AbstractNumbering({
    this.id,
    this.name,
    this.multiLevelType,
    List<NumberingLevel>? levels,
    this.numberingStyleLink,
    this.styleLink,
  }) : levels = levels ?? [];
}

/// A single numbering level definition.
class NumberingLevel {
  int? level;
  String? start;
  int? restart;
  String? format;
  String? text;
  String? justification;
  String? bulletPictureId;
  String? paragraphStyle;
  ParagraphProperties? paragraphProps;
  RunProperties? runProps;

  NumberingLevel({
    this.level,
    this.start,
    this.restart,
    this.format,
    this.text,
    this.justification,
    this.bulletPictureId,
    this.paragraphStyle,
    this.paragraphProps,
    this.runProps,
  });
}

/// Bullet picture in numbering.
class NumberingBulletPicture {
  String? id;
  String? referenceId;
  String? style;

  NumberingBulletPicture({this.id, this.referenceId, this.style});
}

/// Parses the root <numbering> element.
NumberingPartProperties parseNumberingPart(dynamic elem, XmlParser xml) {
  final result = NumberingPartProperties();

  for (final e in xml.elements(elem)) {
    switch (xml.localName(e)) {
      case 'num':
        result.numberings.add(parseNumbering(e, xml));
        break;
      case 'abstractNum':
        result.abstractNumberings.add(parseAbstractNumbering(e, xml));
        break;
      case 'numPicBullet':
        final bp = parseNumberingBulletPicture(e, xml);
        if (bp != null) result.bulletPictures.add(bp);
        break;
    }
  }

  return result;
}

/// Parses a <num> element.
Numbering parseNumbering(dynamic elem, XmlParser xml) {
  final result = Numbering(
    id: xml.attr(elem, 'numId'),
  );

  for (final e in xml.elements(elem)) {
    switch (xml.localName(e)) {
      case 'abstractNumId':
        result.abstractId = xml.attr(e, 'val');
        break;
      case 'lvlOverride':
        result.overrides.add(parseNumberingLevelOverride(e, xml));
        break;
    }
  }

  return result;
}

/// Parses an <abstractNum> element.
AbstractNumbering parseAbstractNumbering(dynamic elem, XmlParser xml) {
  final result = AbstractNumbering(
    id: xml.attr(elem, 'abstractNumId'),
  );

  for (final e in xml.elements(elem)) {
    switch (xml.localName(e)) {
      case 'name':
        result.name = xml.attr(e, 'val');
        break;
      case 'multiLevelType':
        result.multiLevelType = xml.attr(e, 'val');
        break;
      case 'numStyleLink':
        result.numberingStyleLink = xml.attr(e, 'val');
        break;
      case 'styleLink':
        result.styleLink = xml.attr(e, 'val');
        break;
      case 'lvl':
        result.levels.add(parseNumberingLevel(e, xml));
        break;
    }
  }

  return result;
}

/// Parses a <lvl> element.
NumberingLevel parseNumberingLevel(dynamic elem, XmlParser xml) {
  final result = NumberingLevel(
    level: xml.intAttr(elem, 'ilvl'),
  );

  for (final e in xml.elements(elem)) {
    switch (xml.localName(e)) {
      case 'start':
        result.start = xml.attr(e, 'val');
        break;
      case 'lvlRestart':
        result.restart = xml.intAttr(e, 'val');
        break;
      case 'numFmt':
        result.format = xml.attr(e, 'val');
        break;
      case 'lvlText':
        result.text = xml.attr(e, 'val');
        break;
      case 'lvlJc':
        result.justification = xml.attr(e, 'val');
        break;
      case 'lvlPicBulletId':
        result.bulletPictureId = xml.attr(e, 'val');
        break;
      case 'pStyle':
        result.paragraphStyle = xml.attr(e, 'val');
        break;
      case 'pPr':
        result.paragraphProps = parseParagraphProperties(e, xml);
        break;
      case 'rPr':
        result.runProps = parseRunProperties(e, xml);
        break;
    }
  }

  return result;
}

/// Parses a <lvlOverride> element.
NumberingLevelOverride parseNumberingLevelOverride(
    dynamic elem, XmlParser xml) {
  final result = NumberingLevelOverride(
    level: xml.intAttr(elem, 'ilvl'),
  );

  for (final e in xml.elements(elem)) {
    switch (xml.localName(e)) {
      case 'startOverride':
        result.start = xml.intAttr(e, 'val');
        break;
      case 'lvl':
        result.numberingLevel = parseNumberingLevel(e, xml);
        break;
    }
  }

  return result;
}

/// Parses a <numPicBullet> element.
NumberingBulletPicture? parseNumberingBulletPicture(
    dynamic elem, XmlParser xml) {
  final pict = xml.element(elem, 'pict');
  final shape = pict != null ? xml.element(pict, 'shape') : null;
  final imagedata = shape != null ? xml.element(shape, 'imagedata') : null;

  if (imagedata == null) return null;

  return NumberingBulletPicture(
    id: xml.attr(elem, 'numPicBulletId'),
    referenceId: xml.attr(imagedata, 'id'),
    style: xml.attr(shape!, 'style'),
  );
}
