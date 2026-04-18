// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vector_store.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDocumentChunkCollection on Isar {
  IsarCollection<DocumentChunk> get documentChunks => this.collection();
}

const DocumentChunkSchema = CollectionSchema(
  name: r'DocumentChunk',
  id: 8015959461829471676,
  properties: {
    r'addedAt': PropertySchema(
      id: 0,
      name: r'addedAt',
      type: IsarType.dateTime,
    ),
    r'chunkIndex': PropertySchema(
      id: 1,
      name: r'chunkIndex',
      type: IsarType.long,
    ),
    r'chunkText': PropertySchema(
      id: 2,
      name: r'chunkText',
      type: IsarType.string,
    ),
    r'docId': PropertySchema(
      id: 3,
      name: r'docId',
      type: IsarType.string,
    ),
    r'docTitle': PropertySchema(
      id: 4,
      name: r'docTitle',
      type: IsarType.string,
    ),
    r'docType': PropertySchema(
      id: 5,
      name: r'docType',
      type: IsarType.string,
    ),
    r'embedding': PropertySchema(
      id: 6,
      name: r'embedding',
      type: IsarType.doubleList,
    )
  },
  estimateSize: _documentChunkEstimateSize,
  serialize: _documentChunkSerialize,
  deserialize: _documentChunkDeserialize,
  deserializeProp: _documentChunkDeserializeProp,
  idName: r'id',
  indexes: {
    r'docId': IndexSchema(
      id: -9164048795576814174,
      name: r'docId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'docId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'docType': IndexSchema(
      id: 9220672531428353565,
      name: r'docType',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'docType',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _documentChunkGetId,
  getLinks: _documentChunkGetLinks,
  attach: _documentChunkAttach,
  version: '3.1.0+1',
);

int _documentChunkEstimateSize(
  DocumentChunk object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.chunkText.length * 3;
  bytesCount += 3 + object.docId.length * 3;
  bytesCount += 3 + object.docTitle.length * 3;
  bytesCount += 3 + object.docType.length * 3;
  bytesCount += 3 + object.embedding.length * 8;
  return bytesCount;
}

void _documentChunkSerialize(
  DocumentChunk object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.addedAt);
  writer.writeLong(offsets[1], object.chunkIndex);
  writer.writeString(offsets[2], object.chunkText);
  writer.writeString(offsets[3], object.docId);
  writer.writeString(offsets[4], object.docTitle);
  writer.writeString(offsets[5], object.docType);
  writer.writeDoubleList(offsets[6], object.embedding);
}

DocumentChunk _documentChunkDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DocumentChunk();
  object.addedAt = reader.readDateTime(offsets[0]);
  object.chunkIndex = reader.readLong(offsets[1]);
  object.chunkText = reader.readString(offsets[2]);
  object.docId = reader.readString(offsets[3]);
  object.docTitle = reader.readString(offsets[4]);
  object.docType = reader.readString(offsets[5]);
  object.embedding = reader.readDoubleList(offsets[6]) ?? [];
  object.id = id;
  return object;
}

P _documentChunkDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDoubleList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _documentChunkGetId(DocumentChunk object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _documentChunkGetLinks(DocumentChunk object) {
  return [];
}

void _documentChunkAttach(
    IsarCollection<dynamic> col, Id id, DocumentChunk object) {
  object.id = id;
}

extension DocumentChunkQueryWhereSort
    on QueryBuilder<DocumentChunk, DocumentChunk, QWhere> {
  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhere> anyDocType() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'docType'),
      );
    });
  }
}

extension DocumentChunkQueryWhere
    on QueryBuilder<DocumentChunk, DocumentChunk, QWhereClause> {
  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> docIdEqualTo(
      String docId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'docId',
        value: [docId],
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> docIdNotEqualTo(
      String docId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docId',
              lower: [],
              upper: [docId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docId',
              lower: [docId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docId',
              lower: [docId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docId',
              lower: [],
              upper: [docId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> docTypeEqualTo(
      String docType) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'docType',
        value: [docType],
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause>
      docTypeNotEqualTo(String docType) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docType',
              lower: [],
              upper: [docType],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docType',
              lower: [docType],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docType',
              lower: [docType],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docType',
              lower: [],
              upper: [docType],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause>
      docTypeGreaterThan(
    String docType, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'docType',
        lower: [docType],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> docTypeLessThan(
    String docType, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'docType',
        lower: [],
        upper: [docType],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause> docTypeBetween(
    String lowerDocType,
    String upperDocType, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'docType',
        lower: [lowerDocType],
        includeLower: includeLower,
        upper: [upperDocType],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause>
      docTypeStartsWith(String DocTypePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'docType',
        lower: [DocTypePrefix],
        upper: ['$DocTypePrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause>
      docTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'docType',
        value: [''],
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterWhereClause>
      docTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'docType',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'docType',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'docType',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'docType',
              upper: [''],
            ));
      }
    });
  }
}

extension DocumentChunkQueryFilter
    on QueryBuilder<DocumentChunk, DocumentChunk, QFilterCondition> {
  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      addedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      addedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      addedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'addedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      addedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'addedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chunkIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chunkIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chunkIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chunkText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chunkText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chunkText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'chunkText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'chunkText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'chunkText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'chunkText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chunkText',
        value: '',
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      chunkTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'chunkText',
        value: '',
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'docId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'docId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docId',
        value: '',
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'docId',
        value: '',
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'docTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'docTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'docTitle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'docTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'docTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'docTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'docTitle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'docTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'docType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'docType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'docType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'docType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'docType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'docType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'docType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docType',
        value: '',
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      docTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'docType',
        value: '',
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingElementEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'embedding',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'embedding',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      embeddingLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'embedding',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension DocumentChunkQueryObject
    on QueryBuilder<DocumentChunk, DocumentChunk, QFilterCondition> {}

extension DocumentChunkQueryLinks
    on QueryBuilder<DocumentChunk, DocumentChunk, QFilterCondition> {}

extension DocumentChunkQuerySortBy
    on QueryBuilder<DocumentChunk, DocumentChunk, QSortBy> {
  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByChunkIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkIndex', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy>
      sortByChunkIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkIndex', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByChunkText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkText', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy>
      sortByChunkTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkText', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByDocId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docId', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByDocIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docId', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByDocTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docTitle', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy>
      sortByDocTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docTitle', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByDocType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docType', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> sortByDocTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docType', Sort.desc);
    });
  }
}

extension DocumentChunkQuerySortThenBy
    on QueryBuilder<DocumentChunk, DocumentChunk, QSortThenBy> {
  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByAddedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'addedAt', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByChunkIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkIndex', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy>
      thenByChunkIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkIndex', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByChunkText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkText', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy>
      thenByChunkTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chunkText', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByDocId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docId', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByDocIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docId', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByDocTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docTitle', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy>
      thenByDocTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docTitle', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByDocType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docType', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByDocTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docType', Sort.desc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }
}

extension DocumentChunkQueryWhereDistinct
    on QueryBuilder<DocumentChunk, DocumentChunk, QDistinct> {
  QueryBuilder<DocumentChunk, DocumentChunk, QDistinct> distinctByAddedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'addedAt');
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QDistinct> distinctByChunkIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chunkIndex');
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QDistinct> distinctByChunkText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chunkText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QDistinct> distinctByDocId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'docId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QDistinct> distinctByDocTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'docTitle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QDistinct> distinctByDocType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'docType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DocumentChunk, DocumentChunk, QDistinct> distinctByEmbedding() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'embedding');
    });
  }
}

extension DocumentChunkQueryProperty
    on QueryBuilder<DocumentChunk, DocumentChunk, QQueryProperty> {
  QueryBuilder<DocumentChunk, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DocumentChunk, DateTime, QQueryOperations> addedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'addedAt');
    });
  }

  QueryBuilder<DocumentChunk, int, QQueryOperations> chunkIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chunkIndex');
    });
  }

  QueryBuilder<DocumentChunk, String, QQueryOperations> chunkTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chunkText');
    });
  }

  QueryBuilder<DocumentChunk, String, QQueryOperations> docIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'docId');
    });
  }

  QueryBuilder<DocumentChunk, String, QQueryOperations> docTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'docTitle');
    });
  }

  QueryBuilder<DocumentChunk, String, QQueryOperations> docTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'docType');
    });
  }

  QueryBuilder<DocumentChunk, List<double>, QQueryOperations>
      embeddingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'embedding');
    });
  }
}
