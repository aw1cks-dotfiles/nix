#include <liburing.h>

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>

static void published_buffers_are_distinct(unsigned short initial_tail)
{
    unsigned head = 0;
    struct io_uring_sqe submission = {0};
    struct io_uring ring = {
        .sq = {
            .khead = &head,
            .sqes = &submission,
            .ring_mask = 0,
            .ring_entries = 1,
        },
    };
    struct io_uring_sqe *sqe;
    const int sock_fd = 7;

    // Execute the published loop and SQE preparation against userspace memory.
#include "buffer-ring-example.inc"

    assert(buf_ring->tail == (unsigned short)(initial_tail + BUF_COUNT));
    for (unsigned i = 0; i < BUF_COUNT; ++i) {
        const unsigned slot = (initial_tail + i) & (BUF_COUNT - 1);
        const struct io_uring_buf *buffer = &buf_ring->bufs[slot];
        assert(buffer->addr == (uintptr_t)bufs[i]);
        assert(buffer->len == BUF_SIZE);
        assert(buffer->bid == i);
    }
    assert(sqe == &submission);
    assert(sqe->opcode == IORING_OP_RECV);
    assert(sqe->fd == sock_fd);
    assert(sqe->ioprio & IORING_RECV_MULTISHOT);
    assert(sqe->flags & IOSQE_BUFFER_SELECT);
    assert(sqe->buf_group == BUF_GROUP);
    assert(sqe->addr == 0);
    assert(sqe->len == 0);
    free(buf_ring);
}

int main(void)
{
    published_buffers_are_distinct(0);
    published_buffers_are_distinct(BUF_COUNT - 3);
    published_buffers_are_distinct(UINT16_MAX - 3);
    return 0;
}
