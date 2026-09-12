#!/usr/bin/env python3
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"SAFEBOX_IOS_REPLAY_RECOVERY_CONTRACT_FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def first_after(lines, token, start):
    for i in range(start + 1, len(lines)):
        if token in lines[i]:
            return i
    return None


def first_native_after(lines, token, start):
    for i in range(start + 1, len(lines)):
        line = lines[i]
        # NSLog from the main native bridge is represented by SafeBox.debug.dylib.
        # Rust eprintln! is a different unified-log stream ([stderr]) and may be
        # surfaced out of textual order by `log show`, so never mix the streams
        # for causal ordering assertions.
        if '(SafeBox.debug.dylib)' in line and token in line:
            return i
    return None


def main() -> None:
    if len(sys.argv) != 3:
        fail('usage: ios_replay_recovery_contract_check.py <log-file> <protect|unlock>')
    path = Path(sys.argv[1])
    route = sys.argv[2]
    if route not in ('protect', 'unlock'):
        fail('invalid expected route')
    if not path.is_file():
        fail('log file missing')
    lines = path.read_text(errors='replace').splitlines()

    # The shell already scopes log retrieval to the exact latest cold-share arm.
    # Within that transaction window, use the latest extension stage so unrelated
    # pre-stage foreground noise cannot satisfy the proof.
    stages = [i for i, line in enumerate(lines) if 'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS' in line]
    if not stages:
        fail('stage missing in armed transaction')
    start = stages[-1]

    # Cross-stream facts: presence is required inside the armed transaction,
    # but textual order is intentionally NOT compared against native NSLog markers.
    accept = first_after(lines, f'SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route={route}', start)
    rust_ack = first_after(lines, 'SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS:', start)
    if accept is None:
        fail('expected Rust accept marker missing')
    if rust_ack is None:
        fail('Rust ACK marker missing')

    # Single-stream causal proof. These messages are emitted by the native bridge
    # in program order after the Rust callback returns ACK=1.
    claim = first_native_after(lines, 'SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS', start)
    native_ack = first_native_after(lines, 'SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_ACK_PASS', start)
    receipt = first_native_after(lines, 'SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS', start)
    drain1 = first_native_after(lines, 'SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1', start)
    if None in (claim, native_ack, receipt, drain1):
        fail('required native marker missing')
    if not (start < claim < native_ack < receipt < drain1):
        fail('native marker order invalid')

    zero = first_native_after(lines, 'SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=0', drain1)
    if zero is None:
        fail('no zero-work replay proof after accepted drain')
    second_one = first_native_after(lines, 'SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1', drain1)
    if second_one is not None:
        fail('second accepted drain observed after delivery receipt')

    bad = (
        'SAFEBOX_IOS_SHARE_RECOVERY_RUST_NACK',
        'SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_NACK_PASS',
        'SAFEBOX_IOS_SHARE_RECOVERY_RECEIPT_FAIL',
    )
    if any(any(token in line for token in bad) for line in lines[start + 1:]):
        fail('NACK/failure observed')

    print('SAFEBOX_IOS_REPLAY_RECOVERY_ARM_SCOPE_PASS')
    print('SAFEBOX_IOS_REPLAY_RECOVERY_CROSS_STREAM_ACK_PASS')
    print('SAFEBOX_IOS_REPLAY_RECOVERY_NATIVE_ORDER_PASS')
    print('SAFEBOX_IOS_REPLAY_RECOVERY_ZERO_REPLAY_PROOF_PASS')


if __name__ == '__main__':
    main()
