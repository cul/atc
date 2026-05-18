import { useSearchParams } from "react-router";
import { PaginationState, Updater } from "@tanstack/react-table";

const PAGE_SIZE = 50;

export const usePagination = () => {
  const [searchParams, setSearchParams] = useSearchParams();

  const pageFromUrl = parseInt(searchParams.get("page") ?? "1", 10);
  const pageIndex = pageFromUrl > 0 ? pageFromUrl - 1 : 0;

  const pagination: PaginationState = {
    pageIndex,
    pageSize: PAGE_SIZE,
  };

  // TanStack Table calls onPaginationChange with either a new PaginationState
  // or an updater function (prevState) => newState.
  const onPaginationChange = (updater: Updater<PaginationState>) => {
    const newState =
      typeof updater === "function" ? updater(pagination) : updater;

    setSearchParams((prev) => {
      const next = new URLSearchParams(prev);
      // Store 1-based page in URL; don't include the param on page 1 for a cleaner URL
      if (newState.pageIndex <= 0) {
        next.delete("page");
      } else {
        next.set("page", (newState.pageIndex + 1).toString());
      }
      return next;
    });
  };

  return { pagination, onPaginationChange };
};