"""Planning arithmetic using user-supplied, verified prices; not a pricing API."""
import argparse
from decimal import Decimal
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--hours', type=Decimal, required=True)
parser.add_argument('--hourly-subtotal', type=Decimal, required=True)
parser.add_argument('--other', type=Decimal, default=Decimal('0'))
args = parser.parse_args()
if args.hours < 0 or args.hourly_subtotal < 0 or args.other < 0:
    parser.error('All amounts must be nonnegative.')
print(f'Planning estimate: ${(args.hours * args.hourly_subtotal + args.other):.2f} USD')
print('Input-based approximation. Check billing units, rounding, transfer, tax, and retained resources.')
