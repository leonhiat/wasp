import React, { useState } from 'react'
import { useHistory } from 'react-router-dom'

import login from '@wasp/auth/login.js'

const Login = (props) => {

  const LoginForm = () => {
    const history = useHistory()

    const [emailFieldVal, setEmailFieldVal] = useState('')
    const [passwordFieldVal, setPasswordFieldVal] = useState('')

    const handleLogin = async (event) => {
      event.preventDefault()
      try {
        await login(emailFieldVal, passwordFieldVal)

        history.push('/')
      } catch (err) {
        console.log(err)
        window.alert('Error:' + err.message)
      }
    }
    
    return (
      <form onSubmit={handleLogin}>
        <h2>Email</h2>
        <input
          type="text"
          value={emailFieldVal}
          onChange={e => setEmailFieldVal(e.target.value)}
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

  return <LoginForm/>
}

export default Login
