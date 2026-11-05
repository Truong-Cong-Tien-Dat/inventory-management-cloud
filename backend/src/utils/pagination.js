export function buildPaginationMeta({ page, limit, total, sort, order }) {
  const totalPages = total === 0 ? 0 : Math.ceil(total / limit);
  const meta = {
    page,
    limit,
    total,
    totalPages,
    hasNext: page < totalPages,
    hasPrev: page > 1 && totalPages > 0,
  };

  if (sort !== undefined) meta.sort = sort;
  if (order !== undefined) meta.order = order;

  return meta;
}

export function getOffset(page, limit) {
  return (page - 1) * limit;
}
