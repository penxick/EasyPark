// Nonnegative decimal -> integer kopecks. No floating-point multiplication.
export function kopecks(value: string): bigint {
  if (!/^(0|[1-9]\d*)(\.\d{1,2})?$/.test(value))
    throw new Error('Invalid decimal');
  const [whole, fraction = ''] = value.split('.');
  return BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
}
export function decimal(cents: bigint): string {
  return `${cents / 100n}.${(cents % 100n).toString().padStart(2, '0')}`;
}
export function hourlyCost(rate: string, seconds: number): string {
  if (!Number.isSafeInteger(seconds) || seconds < 0)
    throw new Error('Invalid duration');
  return decimal((kopecks(rate) * BigInt(seconds) + 1800n) / 3600n);
}
