{{={= =}=}}
import React, { useState } from 'react'
import { useHistory } from 'react-router-dom'

import login from '../login.js'
import { errorMessage } from '../../utils.js'

const LoginForm = () => {
  const history = useHistory()

  const [usernameFieldVal, setUsernameFieldVal] = useState('')
  const [passwordFieldVal, setPasswordFieldVal] = useState('')

  const handleLogin = async (event) => {
    event.preventDefault()
    try {
      await login(usernameFieldVal, passwordFieldVal)
      // Redirect to configured page, defaults to /.
      history.push('{= onAuthSucceededRedirectTo =}')
    } catch (err) {
      console.log(err)
      window.alert(errorMessage(err))
    }
  }
  
  return (
    <form onSubmit={handleLogin}>
      <h2>Username</h2>
      <input
        type="text"
        value={usernameFieldVal}
        onChange={e => setUsernameFieldVal(e.target.value)}
      />
      <h2>Password</h2>
      <input
        type="password"
        value={passwordFieldVal}
        onChange={e => setPasswordFieldVal(e.target.value)}
      />
      <div>
        <input type="submit" value="Log in"/>
      </div>
    </form>
  )
}

export default LoginForm
