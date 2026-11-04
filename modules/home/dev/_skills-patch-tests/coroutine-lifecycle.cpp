#include "task-example.hpp"

#include <cassert>
#include <stdexcept>
#include <type_traits>
#include <utility>

namespace {

// A coroutine parameter survives suspension and is released with its frame.
struct FrameLease {
    int* releases;

    explicit FrameLease(int& count) : releases(&count) {}
    FrameLease(FrameLease&& other) noexcept
        : releases(std::exchange(other.releases, nullptr)) {}
    FrameLease(const FrameLease&) = delete;
    FrameLease& operator=(const FrameLease&) = delete;
    ~FrameLease() {
        if (releases) ++*releases;
    }
};

Task<int> tracked_task(FrameLease lease, int value) {
    co_return value;
}

Task<int> failing_task(FrameLease lease) {
    throw std::runtime_error("coroutine failure");
    co_return 0;
}

void move_construction_transfers_frame_once() {
    int releases = 0;
    {
        auto source = tracked_task(FrameLease{releases}, 42);
        {
            auto destination = std::move(source);
            assert(!source.handle);
            assert(releases == 0);
            assert(destination.get() == 42);
        }
        assert(releases == 1);
    }
    assert(releases == 1);
}

void move_assignment_releases_previous_frame() {
    int source_releases = 0;
    int destination_releases = 0;
    {
        auto source = tracked_task(FrameLease{source_releases}, 23);
        auto destination = tracked_task(FrameLease{destination_releases}, 17);
        auto& result = (destination = std::move(source));
        assert(&result == &destination);
        assert(!source.handle);
        assert(source_releases == 0);
        assert(destination_releases == 1);
        assert(destination.get() == 23);
    }
    assert(source_releases == 1);
    assert(destination_releases == 1);
}

void self_move_preserves_live_frame() {
    int releases = 0;
    {
        auto task = tracked_task(FrameLease{releases}, 7);
        auto* const alias = &task;
        task = std::move(*alias);
        assert(releases == 0);
        assert(task.get() == 7);
    }
    assert(releases == 1);
}

void moving_empty_tasks_releases_only_owned_frames() {
    int releases = 0;
    {
        Task<int> empty{nullptr};
        auto moved_empty = std::move(empty);
        assert(!empty.handle);
        assert(!moved_empty.handle);

        auto destination = tracked_task(FrameLease{releases}, 9);
        destination = std::move(moved_empty);
        assert(!destination.handle);
        assert(releases == 1);
        destination = std::move(empty);
        auto* const alias = &destination;
        destination = std::move(*alias);
        assert(!destination.handle);
    }
    assert(releases == 1);
}

void moved_failing_task_releases_frame_after_exception() {
    int releases = 0;
    bool caught = false;
    {
        auto source = failing_task(FrameLease{releases});
        auto destination = std::move(source);
        try {
            destination.get();
        } catch (const std::runtime_error&) {
            caught = true;
        }
        assert(caught);
        assert(releases == 0);
    }
    assert(releases == 1);
}

} // namespace

static_assert(std::is_nothrow_move_constructible_v<Task<int>>);
static_assert(std::is_nothrow_move_assignable_v<Task<int>>);
static_assert(!std::is_copy_constructible_v<Task<int>>);
static_assert(!std::is_copy_assignable_v<Task<int>>);

int main() {
    move_construction_transfers_frame_once();
    move_assignment_releases_previous_frame();
    self_move_preserves_live_frame();
    moving_empty_tasks_releases_only_owned_frames();
    moved_failing_task_releases_frame_after_exception();
}
