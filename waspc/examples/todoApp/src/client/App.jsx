import logout from '@wasp/auth/logout.js'
import useAuth from '@wasp/auth/useAuth.js'

import './Main.css'

export function App({ children }) {
  const { data: user } = useAuth()

  return (
    <div className="app border-spacing-2 p-4">
      <header className="flex justify-between">
        <h1 className="font-bold text-3xl mb-5">
          <a href="/">ToDo App</a>
        </h1>
        {user && (
          <div className="flex gap-3 items-center">
            <div>
              Hello, <a href="/profile">{user.username}</a>
            </div>
            <div>
              <button className="btn btn-primary" onClick={logout}>
                Logout
              </button>
            </div>
          </div>
        )}
      </header>
      <main>{children}</main>
      <footer className="mt-8 text-center">Created with Wasp</footer>
    </div>
  )
}
