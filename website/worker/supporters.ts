import type { PolarCore } from "@polar-sh/sdk/core.js";
import { ordersList } from "@polar-sh/sdk/funcs/ordersList.js";

// A full refund takes someone out of the count; a partial one does not.
const COUNTED_STATUSES = new Set<string>(["paid", "partially_refunded"]);

/** How many distinct customers have paid for either supporter product. */
export async function countSupporters(
  polar: PolarCore,
  productIds: string[],
): Promise<number> {
  const customers = new Set<string>();
  const orders = await ordersList(polar, { productId: productIds, limit: 100 });
  for await (const page of orders) {
    if (!page.ok) throw page.error;
    for (const order of page.value.result.items) {
      if (COUNTED_STATUSES.has(order.status)) customers.add(order.customerId);
    }
  }
  return customers.size;
}
