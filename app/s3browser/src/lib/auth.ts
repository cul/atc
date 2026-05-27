import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api-client";
import { User } from "@/types/api";

export const AUTH_QUERY_KEY = ["authenticated-user"];

async function getCurrentUser(): Promise<User | null> {
  try {
    return api.get<User | null>("/users/_self", {
      // Unauthenticated users will be redirected to login page,
      // so we can treat this as a non-error case and avoid showing a toast notification.
      silent: true,
    });
  } catch (error) {
    console.error("Error fetching current user:", error);
    return null;
  }
}

export function useCurrentUser() {
  return useQuery({
    queryKey: AUTH_QUERY_KEY,
    queryFn: getCurrentUser,
    staleTime: 1000 * 60 * 5, // 5 minutes
    gcTime: 1000 * 60 * 30, // 30 minutes cache garbage collection
    retry: false,
  });
}
