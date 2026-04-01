import 'package:naijapulse/core/error/exceptions.dart';
import 'package:naijapulse/core/network/api_client.dart';
import 'package:naijapulse/features/polls/data/models/poll_category_model.dart';
import 'package:naijapulse/features/polls/data/models/poll_model.dart';

abstract class PollsRemoteDataSource {
  Future<List<PollModel>> fetchActivePolls();

  Future<List<PollCategoryModel>> fetchCategories();

  Future<List<PollCategoryModel>> fetchFeedTags();

  Future<PollModel> submitVote({
    required String pollId,
    required String optionId,
    String? idempotencyKey,
  });
}

class PollsRemoteDataSourceImpl implements PollsRemoteDataSource {
  final ApiClient _apiClient;

  const PollsRemoteDataSourceImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<List<PollModel>> fetchActivePolls() async {
    try {
      // Active polls endpoint returns only currently open polls.
      final response = await _apiClient.get('/polls/active');
      final rawItems = response['items'];
      if (rawItems is! List<dynamic>) {
        throw const ParseException('Invalid response format for polls list.');
      }
      return rawItems
          .map((item) => PollModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse active polls response: $error');
    }
  }

  @override
  Future<List<PollCategoryModel>> fetchCategories() async {
    try {
      final response = await _apiClient.get('/categories');
      final rawItems = response['items'];
      if (rawItems is! List<dynamic>) {
        throw const ParseException('Invalid response format for categories.');
      }
      return rawItems
          .map(
            (item) => PollCategoryModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse categories response: $error');
    }
  }

  @override
  Future<List<PollCategoryModel>> fetchFeedTags() async {
    try {
      final response = await _apiClient.get('/tags');
      final rawItems = response['items'];
      if (rawItems is! List<dynamic>) {
        throw const ParseException('Invalid response format for tags.');
      }
      return rawItems
          .map(
            (item) => PollCategoryModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse tags response: $error');
    }
  }

  @override
  Future<PollModel> submitVote({
    required String pollId,
    required String optionId,
    String? idempotencyKey,
  }) async {
    try {
      // Backend expects snake_case payload for vote submissions.
      final payload = <String, dynamic>{'option_id': optionId};
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
        payload['idempotency_key'] = idempotencyKey.trim();
      }
      final response = await _apiClient.post(
        '/polls/$pollId/vote',
        data: payload,
      );
      final rawPoll = response['poll'];
      if (rawPoll is! Map<String, dynamic>) {
        throw const ParseException('Invalid vote response from server.');
      }
      return PollModel.fromJson(rawPoll);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ParseException('Could not parse vote response: $error');
    }
  }
}
