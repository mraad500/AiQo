import Foundation
import SwiftData
import Supabase
import os.log

/// Network layer bridging the Supabase Arena/Tribe schema to local SwiftData models.
/// Supabase network calls are async (the SDK dispatches I/O off the main thread internally).
/// SwiftData writes require `@MainActor`, so the whole service is main-actor-isolated.
@MainActor
final class SupabaseArenaService {

    static let shared = SupabaseArenaService()

    private let client: SupabaseClient
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "ArenaService"
    )

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Supabase DTOs (snake_case ↔ Supabase columns)

    private struct TribeDTO: Codable {
        let id: UUID
        let name: String?
        let owner_id: String?
        let invite_code: String?
        let created_at: String?
        let is_active: Bool?
        let is_frozen: Bool?
        let frozen_at: String?
    }

    private struct TribeMemberDTO: Codable {
        let id: UUID
        let tribe_id: UUID?
        let user_id: String?
        let role: String?
        let contribution_points: Int?
        let joined_at: String?
    }

    private struct TribeWithMembersDTO: Codable {
        let id: UUID
        let name: String?
        let owner_id: String?
        let invite_code: String?
        let created_at: String?
        let is_active: Bool?
        let is_frozen: Bool?
        let frozen_at: String?
        let arena_tribe_members: [TribeMemberDTO]?
    }

    private struct LeaderboardEntryDTO: Codable {
        let id: UUID
        let tribe_id: UUID?
        let challenge_id: UUID?
        let score: Double?
        let rank: Int?
        let joined_at: String?
        let arena_tribes: TribeDTO?
    }

    private struct HallOfFameDTO: Codable {
        let id: UUID
        let tribe_name: String?
        let challenge_title: String?
        let achieved_at: String?
    }

    private struct InsertTribePayload: Encodable {
        let name: String
        let owner_id: String
        let invite_code: String
    }

    private struct InsertMemberPayload: Encodable {
        let tribe_id: UUID
        let user_id: String
        let role: String
    }

    private struct TribeIDRow: Decodable {
        let tribe_id: UUID
    }

    private struct UserProfileDTO: Codable {
        let user_id: String
        let display_name: String?
        let username: String?
        let level: Int?
        let total_points: Int?
        let is_profile_public: Bool?
    }

    private struct MemberWithProfileDTO: Codable {
        let id: UUID
        let tribe_id: UUID?
        let user_id: String?
        let role: String?
        let contribution_points: Int?
        let joined_at: String?
        let profiles: MemberProfileDTO?
    }

    private struct MemberProfileDTO: Codable {
        let display_name: String?
        let username: String?
        let level: Int?
        let total_points: Int?
    }

    private struct TribeWithProfileMembersDTO: Codable {
        let id: UUID
        let name: String?
        let owner_id: String?
        let invite_code: String?
        let created_at: String?
        let is_active: Bool?
        let is_frozen: Bool?
        let frozen_at: String?
        let arena_tribe_members: [MemberWithProfileDTO]?
    }

    private struct InsertParticipationPayload: Encodable {
        let tribe_id: UUID
        let challenge_id: UUID
        let score: Double
    }

    private struct InsertChallengePayload: Encodable {
        let title: String
        let metric: String
        let start_date: String
        let end_date: String
        let is_active: Bool
    }

    private struct WeeklyChallengeDTO: Codable {
        let id: UUID
        let title: String?
        let description_text: String?
        let metric: String?
        let start_date: String?
        let end_date: String?
    }

    // MARK: - ISO 8601 helper

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func date(from string: String?) -> Date {
        guard let string else { return Date() }
        return Self.iso8601.date(from: string) ?? Date()
    }

    // MARK: - Public API

    /// Fetch the global leaderboard and sync to SwiftData.
    func fetchGlobalLeaderboard(limit: Int = 20, context: ModelContext) async throws {
        logger.info("Fetching global leaderboard (limit: \(limit))")

        do {
            let response = try await client
                .from("arena_tribe_participations")
                .select("*, arena_tribes(*)")
                .order("score", ascending: false)
                .limit(limit)
                .execute()

            let entries = try JSONDecoder().decode([LeaderboardEntryDTO].self, from: response.data)
            logger.info("Leaderboard fetched — \(entries.count) entries")

            syncLeaderboard(entries, context: context)
        } catch {
            logger.error("fetchGlobalLeaderboard failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Create a tribe in Supabase and persist to SwiftData.
    @discardableResult
    func createTribe(name: String, context: ModelContext) async throws -> ArenaTribe {
        guard let userID = client.auth.currentUser?.id.uuidString else {
            logger.error("createTribe: no authenticated user")
            throw AiQoError.tribeAccessDenied
        }

        let inviteCode = ArenaTribe.generateInviteCode()
        let payload = InsertTribePayload(
            name: name,
            owner_id: userID,
            invite_code: inviteCode
        )

        logger.info("Creating tribe '\(name)' with code \(inviteCode)")

        do {
            let response = try await client
                .from("arena_tribes")
                .insert(payload)
                .select()
                .single()
                .execute()

            let dto = try JSONDecoder().decode(TribeDTO.self, from: response.data)
            logger.info("Tribe created: \(dto.id)")

            // Auto-add creator as member
            let memberPayload = InsertMemberPayload(
                tribe_id: dto.id,
                user_id: userID,
                role: "owner"
            )
            try await client
                .from("arena_tribe_members")
                .insert(memberPayload)
                .execute()

            logger.info("Creator added as tribe member")

            let tribe = syncCreatedTribe(dto, creatorName: name, context: context)
            return tribe
        } catch {
            logger.error("createTribe failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Join a tribe by invite code and persist to SwiftData.
    @discardableResult
    func joinTribe(inviteCode: String, context: ModelContext) async throws -> ArenaTribe {
        guard let userID = client.auth.currentUser?.id.uuidString else {
            logger.error("joinTribe: no authenticated user")
            throw AiQoError.tribeAccessDenied
        }

        logger.info("Joining tribe with code \(inviteCode)")

        do {
            // Look up the tribe by invite code
            let lookupResponse = try await client
                .from("arena_tribes")
                .select("*, arena_tribe_members(*)")
                .eq("invite_code", value: inviteCode)
                .eq("is_active", value: true)
                .single()
                .execute()

            let tribe = try JSONDecoder().decode(TribeWithMembersDTO.self, from: lookupResponse.data)
            let members = tribe.arena_tribe_members ?? []

            // Check capacity (max 5)
            guard members.count < 5 else {
                logger.warning("Tribe \(tribe.id) is full")
                throw AiQoError.tribeFull
            }

            // Check if already a member
            guard !members.contains(where: { $0.user_id == userID }) else {
                logger.warning("User already in tribe \(tribe.id)")
                throw AiQoError.tribeAlreadyJoined
            }

            // Insert membership
            let payload = InsertMemberPayload(
                tribe_id: tribe.id,
                user_id: userID,
                role: "member"
            )

            try await client
                .from("arena_tribe_members")
                .insert(payload)
                .execute()

            logger.info("Joined tribe \(tribe.id)")

            // Re-fetch for updated member list with profiles
            let refreshed = try await client
                .from("arena_tribes")
                .select("*, arena_tribe_members(*, profiles(display_name, username, level, total_points))")
                .eq("id", value: tribe.id.uuidString)
                .single()
                .execute()

            let updated = try JSONDecoder().decode(TribeWithProfileMembersDTO.self, from: refreshed.data)
            let result = syncTribeWithProfileMembers(updated, context: context)
            return result
        } catch let error as AiQoError {
            throw error
        } catch {
            logger.error("joinTribe failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Fetch the current user's tribe details and sync to SwiftData.
    @discardableResult
    func fetchMyTribeDetails(context: ModelContext) async throws -> ArenaTribe? {
        guard let userID = client.auth.currentUser?.id.uuidString else {
            logger.error("fetchMyTribeDetails: no authenticated user")
            throw AiQoError.tribeAccessDenied
        }

        logger.info("Fetching tribe details for user \(userID)")

        do {
            // Find tribe membership
            let memberResponse = try await client
                .from("arena_tribe_members")
                .select("tribe_id")
                .eq("user_id", value: userID)
                .limit(1)
                .execute()

            let rows = try JSONDecoder().decode([TribeIDRow].self, from: memberResponse.data)

            guard let tribeID = rows.first?.tribe_id else {
                logger.info("User has no tribe")
                return nil
            }

            // Fetch tribe with members AND their profiles (resolves UUID display bug)
            let tribeResponse = try await client
                .from("arena_tribes")
                .select("*, arena_tribe_members(*, profiles(display_name, username, level, total_points))")
                .eq("id", value: tribeID.uuidString)
                .single()
                .execute()

            let dto = try JSONDecoder().decode(TribeWithProfileMembersDTO.self, from: tribeResponse.data)
            let memberCount = dto.arena_tribe_members?.count ?? 0
            logger.info("Fetched tribe \(dto.name ?? "?") with \(memberCount) members")

            let tribe = syncTribeWithProfileMembers(dto, context: context)
            return tribe
        } catch {
            logger.error("fetchMyTribeDetails failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Leave the current user's tribe.
    func leaveTribe(context: ModelContext) async throws {
        guard let userID = client.auth.currentUser?.id.uuidString else {
            logger.error("leaveTribe: no authenticated user")
            throw AiQoError.tribeAccessDenied
        }

        logger.info("Leaving tribe for user \(userID)")

        do {
            // Find the user's membership to get tribe_id
            let memberResponse = try await client
                .from("arena_tribe_members")
                .select("id, tribe_id, role")
                .eq("user_id", value: userID)
                .limit(1)
                .execute()

            struct MemberRow: Decodable {
                let id: UUID
                let tribe_id: UUID
                let role: String?
            }

            let rows = try JSONDecoder().decode([MemberRow].self, from: memberResponse.data)
            guard let membership = rows.first else {
                logger.info("User has no tribe to leave")
                return
            }

            let isOwner = membership.role == "owner"

            // Remove the member
            try await client
                .from("arena_tribe_members")
                .delete()
                .eq("id", value: membership.id.uuidString)
                .execute()

            logger.info("Removed membership \(membership.id)")

            // If owner, check remaining members
            if isOwner {
                let remainingResponse = try await client
                    .from("arena_tribe_members")
                    .select("id, user_id, joined_at")
                    .eq("tribe_id", value: membership.tribe_id.uuidString)
                    .order("joined_at", ascending: true)
                    .limit(1)
                    .execute()

                struct RemainingRow: Decodable {
                    let id: UUID
                    let user_id: String
                }

                let remaining = try JSONDecoder().decode([RemainingRow].self, from: remainingResponse.data)

                if let nextMember = remaining.first {
                    // Transfer ownership
                    try await client
                        .from("arena_tribe_members")
                        .update(["role": "owner"])
                        .eq("id", value: nextMember.id.uuidString)
                        .execute()

                    try await client
                        .from("arena_tribes")
                        .update(["owner_id": nextMember.user_id])
                        .eq("id", value: membership.tribe_id.uuidString)
                        .execute()

                    logger.info("Ownership transferred to \(nextMember.user_id)")
                } else {
                    // No members left — deactivate tribe
                    try await client
                        .from("arena_tribes")
                        .update(["is_active": false])
                        .eq("id", value: membership.tribe_id.uuidString)
                        .execute()

                    logger.info("Tribe deactivated (no members remain)")
                }
            }

            // Clear local SwiftData
            let tribeID = membership.tribe_id
            let descriptor = FetchDescriptor<ArenaTribe>(
                predicate: #Predicate { $0.id == tribeID }
            )
            if let localTribe = try? context.fetch(descriptor).first {
                for member in localTribe.members {
                    context.delete(member)
                }
                context.delete(localTribe)
                saveContext(context)
            }

            logger.info("Left tribe successfully")
        } catch let error as AiQoError {
            throw error
        } catch {
            logger.error("leaveTribe failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Submit a participation score for the current tribe and challenge.
    func submitParticipation(tribeId: UUID, challengeId: UUID, value: Double) async throws {
        logger.info("Submitting participation: tribe=\(tribeId), challenge=\(challengeId), value=\(value)")

        do {
            let payload = InsertParticipationPayload(
                tribe_id: tribeId,
                challenge_id: challengeId,
                score: value
            )
            try await client
                .from("arena_tribe_participations")
                .upsert(payload)
                .execute()

            logger.info("Participation submitted successfully")
        } catch {
            logger.error("submitParticipation failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Fetch participation data for a tribe in a specific challenge.
    func fetchTribeParticipation(tribeId: UUID, challengeId: UUID) async throws -> Double {
        logger.info("Fetching tribe participation: tribe=\(tribeId), challenge=\(challengeId)")

        do {
            let response = try await client
                .from("arena_tribe_participations")
                .select("score")
                .eq("tribe_id", value: tribeId.uuidString)
                .eq("challenge_id", value: challengeId.uuidString)
                .limit(1)
                .execute()

            struct ScoreRow: Decodable { let score: Double? }
            let rows = try JSONDecoder().decode([ScoreRow].self, from: response.data)
            return rows.first?.score ?? 0
        } catch {
            logger.error("fetchTribeParticipation failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Create a default weekly challenge when none exists.
    func createDefaultChallenge(context: ModelContext) async throws -> ArenaWeeklyChallenge {
        logger.info("Creating default weekly challenge")

        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        // Calculate Monday (weekday 2 in gregorian)
        let daysToMonday = weekday == 1 ? -6 : (2 - weekday)
        let monday = cal.date(byAdding: .day, value: daysToMonday, to: cal.startOfDay(for: now)) ?? now
        let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? now
        let endOfSunday = cal.date(bySettingHour: 23, minute: 59, second: 59, of: sunday) ?? sunday

        let payload = InsertChallengePayload(
            title: "أكثر قبيلة ملتزمة بالتمارين",
            metric: ArenaChallengeMetric.consistency.rawValue,
            start_date: Self.iso8601.string(from: monday),
            end_date: Self.iso8601.string(from: endOfSunday),
            is_active: true
        )

        do {
            let response = try await client
                .from("arena_weekly_challenges")
                .insert(payload)
                .select()
                .single()
                .execute()

            let dto = try JSONDecoder().decode(WeeklyChallengeDTO.self, from: response.data)

            let challenge = ArenaWeeklyChallenge(
                title: dto.title ?? "أكثر قبيلة ملتزمة بالتمارين",
                descriptionText: dto.description_text ?? "معدل أيام التمرين لكل فرد بالقبيلة خلال الأسبوع",
                metric: ArenaChallengeMetric(rawValue: dto.metric ?? "") ?? .consistency,
                startDate: date(from: dto.start_date),
                endDate: date(from: dto.end_date)
            )
            challenge.id = dto.id
            context.insert(challenge)
            saveContext(context)

            logger.info("Default challenge created: \(challenge.title)")
            return challenge
        } catch {
            logger.error("createDefaultChallenge failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Sync XP and level to the Supabase profiles table.
    func syncUserStats(totalPoints: Int, level: Int) async {
        guard let userID = client.auth.currentUser?.id else {
            logger.warning("syncUserStats: no authenticated user")
            return
        }

        do {
            try await client
                .from("profiles")
                .update(["total_points": totalPoints, "level": level])
                .eq("user_id", value: userID)
                .execute()

            logger.info("User stats synced: points=\(totalPoints), level=\(level)")
        } catch {
            logger.error("syncUserStats failed: \(error.localizedDescription)")
            CrashReporter.shared.recordError(error, context: "syncUserStats")
        }
    }

    /// Fetch the global user leaderboard (individual users ranked by total_points).
    func fetchGlobalUserLeaderboard(limit: Int = 50) async throws -> [GlobalUserRow] {
        logger.info("Fetching global user leaderboard (limit: \(limit))")

        do {
            let response = try await client
                .from("profiles")
                .select("user_id, display_name, username, level, total_points, is_profile_public")
                .order("total_points", ascending: false)
                .limit(limit)
                .execute()

            let dtos = try JSONDecoder().decode([UserProfileDTO].self, from: response.data)
            logger.info("User leaderboard fetched — \(dtos.count) profiles")

            return dtos.enumerated().map { index, dto in
                GlobalUserRow(
                    id: dto.user_id,
                    displayName: dto.display_name ?? "",
                    username: dto.username ?? "",
                    level: dto.level ?? 1,
                    points: dto.total_points ?? 0,
                    isProfilePublic: dto.is_profile_public ?? true,
                    rank: index + 1
                )
            }
        } catch {
            logger.error("fetchGlobalUserLeaderboard failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Fetch the current (active) weekly challenge and sync to SwiftData.
    func fetchCurrentChallenge(context: ModelContext) async throws -> ArenaWeeklyChallenge? {
        logger.info("Fetching current weekly challenge")

        do {
            let now = Self.iso8601.string(from: Date())
            let response = try await client
                .from("arena_weekly_challenges")
                .select()
                .gte("end_date", value: now)
                .order("start_date", ascending: true)
                .limit(1)
                .execute()

            let dtos = try JSONDecoder().decode([WeeklyChallengeDTO].self, from: response.data)
            guard let dto = dtos.first else {
                logger.info("No active weekly challenge found")
                return nil
            }

            let challengeID = dto.id
            let descriptor = FetchDescriptor<ArenaWeeklyChallenge>(
                predicate: #Predicate { $0.id == challengeID }
            )
            let challenge: ArenaWeeklyChallenge
            if let existing = try? context.fetch(descriptor).first {
                challenge = existing
            } else {
                challenge = ArenaWeeklyChallenge(
                    title: dto.title ?? "",
                    descriptionText: dto.description_text ?? "",
                    metric: ArenaChallengeMetric(rawValue: dto.metric ?? "") ?? .consistency,
                    startDate: date(from: dto.start_date),
                    endDate: date(from: dto.end_date)
                )
                challenge.id = dto.id
                context.insert(challenge)
            }

            challenge.title = dto.title ?? challenge.title
            challenge.descriptionText = dto.description_text ?? challenge.descriptionText
            challenge.metric = ArenaChallengeMetric(rawValue: dto.metric ?? "") ?? challenge.metric
            challenge.startDate = date(from: dto.start_date)
            challenge.endDate = date(from: dto.end_date)

            saveContext(context)
            logger.info("Current challenge synced: \(challenge.title)")
            return challenge
        } catch {
            logger.error("fetchCurrentChallenge failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    /// Fetch hall of fame entries and sync to SwiftData.
    func fetchHallOfFame(limit: Int = 50, context: ModelContext) async throws {
        logger.info("Fetching hall of fame")

        do {
            let response = try await client
                .from("arena_hall_of_fame_entries")
                .select()
                .order("achieved_at", ascending: false)
                .limit(limit)
                .execute()

            let entries = try JSONDecoder().decode([HallOfFameDTO].self, from: response.data)
            logger.info("Hall of fame fetched — \(entries.count) entries")

            syncHallOfFame(entries, context: context)
        } catch {
            logger.error("fetchHallOfFame failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    // MARK: - SwiftData Sync (MainActor)

    private func syncLeaderboard(_ entries: [LeaderboardEntryDTO], context: ModelContext) {
        for entry in entries {
            guard let dto = entry.arena_tribes else { continue }
            let tribe = findOrCreateTribe(dto, in: context)
            tribe.isActive = dto.is_active ?? true

            let participation = findOrCreateParticipation(id: entry.id, in: context) {
                ArenaTribeParticipation(
                    currentScore: entry.score ?? 0,
                    rank: entry.rank ?? 0
                )
            }
            participation.currentScore = entry.score ?? 0
            participation.rank = entry.rank ?? 0
            participation.tribe = tribe
        }

        saveContext(context)
        logger.info("Leaderboard synced to SwiftData")
    }

    private func syncCreatedTribe(_ dto: TribeDTO, creatorName: String, context: ModelContext) -> ArenaTribe {
        let tribe = findOrCreateTribe(dto, in: context)

        // Use local profile name for the creator (current user)
        let localProfile = UserProfileStore.shared.current
        let displayName = localProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? creatorName
            : localProfile.name

        let member = ArenaTribeMember(
            userID: dto.owner_id ?? "",
            displayName: displayName,
            initials: Self.resolveInitials(from: displayName),
            isCreator: true
        )
        member.tribe = tribe
        context.insert(member)
        tribe.members.append(member)

        saveContext(context)
        logger.info("Created tribe synced to SwiftData")
        return tribe
    }

    private func syncTribeWithMembers(_ dto: TribeWithMembersDTO, context: ModelContext) -> ArenaTribe {
        let tribeDTO = TribeDTO(
            id: dto.id,
            name: dto.name,
            owner_id: dto.owner_id,
            invite_code: dto.invite_code,
            created_at: dto.created_at,
            is_active: dto.is_active,
            is_frozen: dto.is_frozen,
            frozen_at: dto.frozen_at
        )
        let tribe = findOrCreateTribe(tribeDTO, in: context)
        syncMembers(dto.arena_tribe_members ?? [], for: tribe, in: context)
        saveContext(context)
        logger.info("Tribe with members synced to SwiftData")
        return tribe
    }

    private func syncTribeWithProfileMembers(_ dto: TribeWithProfileMembersDTO, context: ModelContext) -> ArenaTribe {
        let tribeDTO = TribeDTO(
            id: dto.id,
            name: dto.name,
            owner_id: dto.owner_id,
            invite_code: dto.invite_code,
            created_at: dto.created_at,
            is_active: dto.is_active,
            is_frozen: dto.is_frozen,
            frozen_at: dto.frozen_at
        )
        let tribe = findOrCreateTribe(tribeDTO, in: context)

        // Clear existing members and rebuild with profile data
        for existingMember in tribe.members {
            context.delete(existingMember)
        }
        tribe.members.removeAll()

        let currentUserID = client.auth.currentUser?.id.uuidString

        for memberDTO in (dto.arena_tribe_members ?? []) {
            let userID = memberDTO.user_id ?? ""
            let isCreator = (memberDTO.role ?? "") == "owner"
            let isCurrentUser = userID == currentUserID

            // Resolve display name: current user → local profile, others → Supabase profile
            let displayName: String
            if isCurrentUser {
                let localProfile = UserProfileStore.shared.current
                let localName = localProfile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                displayName = localName.isEmpty ? (memberDTO.profiles?.display_name ?? "عضو") : localName
            } else {
                displayName = memberDTO.profiles?.display_name ?? "عضو"
            }

            let initials = Self.resolveInitials(from: displayName)

            let member = ArenaTribeMember(
                userID: userID,
                displayName: displayName,
                initials: initials,
                isCreator: isCreator
            )
            member.id = memberDTO.id
            member.joinedAt = date(from: memberDTO.joined_at)
            member.tribe = tribe
            context.insert(member)
            tribe.members.append(member)
        }

        saveContext(context)
        logger.info("Tribe with profile members synced to SwiftData")
        return tribe
    }

    /// Extract initials from a display name (supports Arabic + Latin)
    private static func resolveInitials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "AQ" }
        let words = trimmed.split(separator: " ").prefix(2)
        if words.count > 1 {
            return words.compactMap(\.first).map(String.init).joined()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    private func syncHallOfFame(_ entries: [HallOfFameDTO], context: ModelContext) {
        for (index, dto) in entries.enumerated() {
            let entry = findOrCreateHallOfFame(id: dto.id, in: context) {
                ArenaHallOfFameEntry(
                    weekNumber: index,
                    tribeName: dto.tribe_name ?? "",
                    challengeTitle: dto.challenge_title ?? "",
                    date: date(from: dto.achieved_at)
                )
            }
            entry.weekNumber = index
            entry.tribeName = dto.tribe_name ?? ""
            entry.challengeTitle = dto.challenge_title ?? ""
        }

        saveContext(context)
        logger.info("Hall of fame synced to SwiftData")
    }

    // MARK: - SwiftData Helpers

    private func findOrCreateTribe(_ dto: TribeDTO, in context: ModelContext) -> ArenaTribe {
        let tribeID = dto.id
        let descriptor = FetchDescriptor<ArenaTribe>(
            predicate: #Predicate { $0.id == tribeID }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.name = dto.name ?? existing.name
            existing.inviteCode = dto.invite_code ?? existing.inviteCode
            existing.isActive = dto.is_active ?? existing.isActive
            existing.isFrozen = dto.is_frozen ?? existing.isFrozen
            existing.frozenAt = dto.frozen_at.flatMap { date(from: $0) }
            return existing
        }

        let tribe = ArenaTribe(name: dto.name ?? "", creatorUserID: dto.owner_id ?? "")
        tribe.id = dto.id
        tribe.inviteCode = dto.invite_code ?? ""
        tribe.createdAt = date(from: dto.created_at)
        tribe.isActive = dto.is_active ?? true
        tribe.isFrozen = dto.is_frozen ?? false
        tribe.frozenAt = dto.frozen_at.flatMap { date(from: $0) }
        context.insert(tribe)
        return tribe
    }

    private func syncMembers(_ dtos: [TribeMemberDTO], for tribe: ArenaTribe, in context: ModelContext) {
        let existingIDs = Set(tribe.members.map(\.id))
        let currentUserID = client.auth.currentUser?.id.uuidString

        for dto in dtos {
            if existingIDs.contains(dto.id) { continue }

            let isCreator = (dto.role ?? "") == "owner"
            let userID = dto.user_id ?? ""
            let isCurrentUser = userID == currentUserID

            // Avoid showing UUID as display name
            let displayName: String
            if isCurrentUser {
                let localName = UserProfileStore.shared.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
                displayName = localName.isEmpty ? "أنت" : localName
            } else {
                displayName = "عضو" // Fallback; will be resolved when profile data is fetched
            }

            let member = ArenaTribeMember(
                userID: userID,
                displayName: displayName,
                initials: Self.resolveInitials(from: displayName),
                isCreator: isCreator
            )
            member.id = dto.id
            member.joinedAt = date(from: dto.joined_at)
            member.tribe = tribe
            context.insert(member)
            tribe.members.append(member)
        }
    }

    private func findOrCreateParticipation(
        id: UUID,
        in context: ModelContext,
        factory: () -> ArenaTribeParticipation
    ) -> ArenaTribeParticipation {
        let descriptor = FetchDescriptor<ArenaTribeParticipation>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let new = factory()
        context.insert(new)
        return new
    }

    private func findOrCreateHallOfFame(
        id: UUID,
        in context: ModelContext,
        factory: () -> ArenaHallOfFameEntry
    ) -> ArenaHallOfFameEntry {
        let descriptor = FetchDescriptor<ArenaHallOfFameEntry>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let new = factory()
        context.insert(new)
        return new
    }

    // MARK: - Profile Visibility

    /// Update the current user's `is_profile_public` flag on the Supabase `profiles` table.
    func updateProfileVisibility(isPublic: Bool) async throws {
        guard let userID = client.auth.currentUser?.id else {
            logger.error("updateProfileVisibility: no authenticated user")
            throw AiQoError.notAuthenticated
        }

        logger.info("Updating profile visibility → \(isPublic ? "public" : "private")")

        do {
            try await client
                .from("profiles")
                .update(["is_profile_public": isPublic])
                .eq("user_id", value: userID)
                .execute()

            logger.info("Profile visibility updated successfully")
        } catch {
            logger.error("updateProfileVisibility failed: \(error.localizedDescription)")
            throw AiQoError.from(error)
        }
    }

    // MARK: - Domain snapshots for Tribe UI

    func fetchCurrentTribeSnapshot() async throws -> TribeRepositorySnapshot {
        guard let userID = client.auth.currentUser?.id.uuidString else {
            logger.error("fetchCurrentTribeSnapshot: no authenticated user")
            throw AiQoError.tribeAccessDenied
        }

        let memberResponse = try await client
            .from("arena_tribe_members")
            .select("tribe_id")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()

        let rows = try JSONDecoder().decode([TribeIDRow].self, from: memberResponse.data)
        guard let tribeID = rows.first?.tribe_id else {
            return TribeRepositorySnapshot(tribe: nil, members: [], missions: [], events: [])
        }

        let tribeResponse = try await client
            .from("arena_tribes")
            .select("*, arena_tribe_members(*, profiles(display_name, username, level, total_points))")
            .eq("id", value: tribeID.uuidString)
            .single()
            .execute()

        let dto = try JSONDecoder().decode(TribeWithProfileMembersDTO.self, from: tribeResponse.data)
        return makeTribeSnapshot(from: dto, currentUserID: userID)
    }

    func createTribeSnapshot(name: String) async throws -> TribeRepositorySnapshot {
        guard let userID = client.auth.currentUser?.id.uuidString else {
            logger.error("createTribeSnapshot: no authenticated user")
            throw AiQoError.tribeAccessDenied
        }

        let payload = InsertTribePayload(
            name: name,
            owner_id: userID,
            invite_code: ArenaTribe.generateInviteCode()
        )

        let response = try await client
            .from("arena_tribes")
            .insert(payload)
            .select()
            .single()
            .execute()

        let tribe = try JSONDecoder().decode(TribeDTO.self, from: response.data)

        let memberPayload = InsertMemberPayload(
            tribe_id: tribe.id,
            user_id: userID,
            role: "owner"
        )
        try await client
            .from("arena_tribe_members")
            .insert(memberPayload)
            .execute()

        return try await fetchTribeSnapshot(tribeID: tribe.id, currentUserID: userID)
    }

    func joinTribeSnapshot(inviteCode: String) async throws -> TribeRepositorySnapshot {
        guard let userID = client.auth.currentUser?.id.uuidString else {
            logger.error("joinTribeSnapshot: no authenticated user")
            throw AiQoError.tribeAccessDenied
        }

        let lookupResponse = try await client
            .from("arena_tribes")
            .select("*, arena_tribe_members(*)")
            .eq("invite_code", value: inviteCode)
            .eq("is_active", value: true)
            .single()
            .execute()

        let tribe = try JSONDecoder().decode(TribeWithMembersDTO.self, from: lookupResponse.data)
        let members = tribe.arena_tribe_members ?? []

        guard members.count < 5 else {
            throw AiQoError.tribeFull
        }

        guard !members.contains(where: { $0.user_id == userID }) else {
            throw AiQoError.tribeAlreadyJoined
        }

        let payload = InsertMemberPayload(
            tribe_id: tribe.id,
            user_id: userID,
            role: "member"
        )

        try await client
            .from("arena_tribe_members")
            .insert(payload)
            .execute()

        return try await fetchTribeSnapshot(tribeID: tribe.id, currentUserID: userID)
    }

    func leaveCurrentTribe() async throws {
        guard let userID = client.auth.currentUser?.id.uuidString else {
            logger.error("leaveCurrentTribe: no authenticated user")
            throw AiQoError.tribeAccessDenied
        }

        let memberResponse = try await client
            .from("arena_tribe_members")
            .select("id, tribe_id, role")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()

        struct MemberRow: Decodable {
            let id: UUID
            let tribe_id: UUID
            let role: String?
        }

        let rows = try JSONDecoder().decode([MemberRow].self, from: memberResponse.data)
        guard let membership = rows.first else {
            return
        }

        try await client
            .from("arena_tribe_members")
            .delete()
            .eq("id", value: membership.id.uuidString)
            .execute()

        if membership.role == "owner" {
            let remainingResponse = try await client
                .from("arena_tribe_members")
                .select("id, user_id, joined_at")
                .eq("tribe_id", value: membership.tribe_id.uuidString)
                .order("joined_at", ascending: true)
                .limit(1)
                .execute()

            struct RemainingRow: Decodable {
                let id: UUID
                let user_id: String
            }

            let remaining = try JSONDecoder().decode([RemainingRow].self, from: remainingResponse.data)

            if let nextMember = remaining.first {
                try await client
                    .from("arena_tribe_members")
                    .update(["role": "owner"])
                    .eq("id", value: nextMember.id.uuidString)
                    .execute()

                try await client
                    .from("arena_tribes")
                    .update(["owner_id": nextMember.user_id])
                    .eq("id", value: membership.tribe_id.uuidString)
                    .execute()
            } else {
                try await client
                    .from("arena_tribes")
                    .update(["is_active": false])
                    .eq("id", value: membership.tribe_id.uuidString)
                    .execute()
            }
        }
    }

    func fetchLiveChallenges() async throws -> [TribeChallenge] {
        let currentUserID = client.auth.currentUser?.id.uuidString
        let response = try await client
            .from("arena_weekly_challenges")
            .select()
            .gte("end_date", value: Self.iso8601.string(from: Date()))
            .order("start_date", ascending: true)
            .limit(1)
            .execute()

        let dtos = try JSONDecoder().decode([WeeklyChallengeDTO].self, from: response.data)
        guard let dto = dtos.first else { return [] }

        let startDate = date(from: dto.start_date)
        let endDate = date(from: dto.end_date)
        let cadence: ChallengeCadence = endDate.timeIntervalSince(startDate) > 60 * 60 * 24 ? .monthly : .daily
        let metricType = mapLiveMetric(dto.metric)
        let title = dto.title ?? "تحدي الأسبوع"
        let subtitle = dto.description_text ?? "تحدي حي من سحابة AiQo."

        var challenges: [TribeChallenge] = []
        var liveParticipantCount = 0
        var tribeProgress = 0

        if let currentUserID,
           let snapshot = try? await fetchCurrentTribeSnapshot(),
           let tribe = snapshot.tribe,
           let tribeID = UUID(uuidString: tribe.id) {
            tribeProgress = Int((try? await fetchTribeParticipation(tribeId: tribeID, challengeId: dto.id)) ?? 0)
            liveParticipantCount = max(snapshot.members.count, 1)

            challenges.append(
                TribeChallenge(
                    id: "live-tribe-\(dto.id.uuidString)",
                    scope: .tribe,
                    cadence: cadence,
                    title: title,
                    subtitle: subtitle,
                    metricType: metricType,
                    targetValue: max(tribeProgress + 10, 50),
                    progressValue: tribeProgress,
                    endAt: endDate,
                    createdByUserId: currentUserID,
                    participantsCount: liveParticipantCount
                )
            )
        }

        challenges.append(
            TribeChallenge(
                id: "live-galaxy-\(dto.id.uuidString)",
                scope: .galaxy,
                cadence: cadence,
                title: title,
                subtitle: subtitle,
                metricType: metricType,
                targetValue: max(tribeProgress + 25, 100),
                progressValue: tribeProgress,
                endAt: endDate,
                isCuratedGlobal: true,
                participantsCount: max(liveParticipantCount, 1)
            )
        )

        return challenges
    }

    func fetchLiveCuratedGalaxyChallenges() async throws -> [TribeChallenge] {
        try await fetchLiveChallenges().filter { $0.scope == .galaxy }
    }

    private func fetchTribeSnapshot(
        tribeID: UUID,
        currentUserID: String
    ) async throws -> TribeRepositorySnapshot {
        let tribeResponse = try await client
            .from("arena_tribes")
            .select("*, arena_tribe_members(*, profiles(display_name, username, level, total_points))")
            .eq("id", value: tribeID.uuidString)
            .single()
            .execute()

        let dto = try JSONDecoder().decode(TribeWithProfileMembersDTO.self, from: tribeResponse.data)
        return makeTribeSnapshot(from: dto, currentUserID: currentUserID)
    }

    private func makeTribeSnapshot(
        from dto: TribeWithProfileMembersDTO,
        currentUserID: String
    ) -> TribeRepositorySnapshot {
        let calendar = Calendar.current
        let tribe = Tribe(
            id: dto.id.uuidString,
            name: dto.name ?? "AiQo Tribe",
            ownerUserId: dto.owner_id ?? "",
            inviteCode: dto.invite_code ?? "",
            createdAt: date(from: dto.created_at)
        )

        let members = (dto.arena_tribe_members ?? [])
            .map { memberDTO in
                let userID = memberDTO.user_id ?? memberDTO.id.uuidString
                let localProfile = UserProfileStore.shared.current
                let fallbackName = localProfile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "tribe.member.anonymous".localized
                    : localProfile.name
                let baseName = memberDTO.profiles?.display_name
                    ?? memberDTO.profiles?.username
                    ?? (userID == currentUserID ? fallbackName : "tribe.member.anonymous".localized)
                let privacyMode: PrivacyMode = userID == currentUserID ? UserProfileStore.shared.tribePrivacyMode : .public
                let role = mapRole(memberDTO.role)

                return TribeMember(
                    id: userID,
                    userId: userID,
                    displayName: baseName,
                    displayNamePublic: baseName,
                    displayNamePrivate: privacyMode == .public ? baseName : "tribe.member.anonymous".localized,
                    avatarURL: nil,
                    level: max(memberDTO.profiles?.level ?? 1, 1),
                    privacyMode: privacyMode,
                    energyContributionToday: max(memberDTO.contribution_points ?? 0, 0),
                    initials: Self.resolveInitials(from: baseName),
                    isLeader: role == .owner,
                    role: role
                )
            }
            .sorted {
                if $0.role == $1.role {
                    return $0.energyContributionToday > $1.energyContributionToday
                }
                return $0.role == .owner
            }

        let totalEnergy = members.reduce(0) { $0 + $1.energyContributionToday }
        let now = Date()
        let missions = [
            TribeMission(
                id: "mission-energy",
                title: "tribe.store.mission.energy".localized,
                targetValue: max(totalEnergy + 100, 500),
                progressValue: totalEnergy,
                endsAt: calendar.date(byAdding: .day, value: 1, to: now) ?? now
            ),
            TribeMission(
                id: "mission-checkin",
                title: "tribe.store.mission.checkin".localized,
                targetValue: 5,
                progressValue: min(members.count, 5),
                endsAt: calendar.date(byAdding: .hour, value: 12, to: now) ?? now
            ),
            TribeMission(
                id: "mission-streak",
                title: "tribe.store.mission.streak".localized,
                targetValue: 8,
                progressValue: min(max(members.filter { $0.energyContributionToday > 0 }.count, 1), 8),
                endsAt: calendar.date(byAdding: .day, value: 1, to: now) ?? now
            )
        ]

        let createdEvent = TribeEvent(
            id: "created-\(tribe.id)",
            type: .join,
                actorId: tribe.ownerUserId,
                actorDisplayName: members.first(where: { $0.userId == tribe.ownerUserId })?.visibleDisplayName ?? tribe.name,
                message: String(
                    format: "tribe.event.created".localized,
                    locale: Locale.current,
                    arguments: [
                        members.first(where: { $0.userId == tribe.ownerUserId })?.visibleDisplayName ?? tribe.name
                    ]
                ),
                createdAt: tribe.createdAt
            )

        var events = [createdEvent]
        if let latestContributor = members.max(by: { $0.energyContributionToday < $1.energyContributionToday }),
           latestContributor.energyContributionToday > 0 {
            events.insert(
                TribeEvent(
                    id: "contribution-\(latestContributor.id)",
                    type: .contribution,
                    actorId: latestContributor.id,
                    actorDisplayName: latestContributor.visibleDisplayName,
                    message: String(
                        format: "tribe.event.contribution".localized,
                        locale: Locale.current,
                        arguments: [
                            latestContributor.visibleDisplayName,
                            latestContributor.energyContributionToday
                        ]
                    ),
                    value: latestContributor.energyContributionToday,
                    createdAt: now.addingTimeInterval(-900)
                ),
                at: 0
            )
        }

        return TribeRepositorySnapshot(
            tribe: tribe,
            members: members,
            missions: missions,
            events: events.sorted { $0.createdAt > $1.createdAt }
        )
    }

    private func mapLiveMetric(_ rawValue: String?) -> TribeChallengeMetricType {
        switch ArenaChallengeMetric(rawValue: rawValue ?? "") {
        case .avgSteps:
            return .steps
        case .avgSleepScore:
            return .sleep
        case .avgCalories:
            return .custom
        case .avgWorkoutDays, .consistency, .none:
            return .minutes
        }
    }

    private func mapRole(_ rawValue: String?) -> TribeMemberRole {
        switch rawValue {
        case "owner":
            return .owner
        case "admin":
            return .admin
        default:
            return .member
        }
    }

    private func saveContext(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.fault("SwiftData save failed: \(error.localizedDescription)")
        }
    }
}
