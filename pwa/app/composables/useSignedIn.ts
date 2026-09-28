/** For pages behind the login: goes to /login when nobody is signed in, else opens the notes. Returns whether to go on. */
export async function useSignedIn(): Promise<boolean> {
  const { user, refresh } = useAccount();
  if (user.value === undefined) await refresh();
  if (!user.value) {
    await navigateTo("/login");
    return false;
  }
  await useNotes().start(user.value.id, () => {
    user.value = null;
    void navigateTo("/login?expired=1");
  });
  useLive().start();
  return true;
}
