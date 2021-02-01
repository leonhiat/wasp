{{={= =}=}}
import React from 'react'

import { Redirect, Link } from 'react-router-dom'
import useAuth from '../../auth/useAuth.js'


const createAuthRequiredPage = (Page) => {
  return (props) => {
    const { data: user, isError, isSuccess, isLoading, isFetching, status } = useAuth()

    if (isSuccess) {
      if (user) {
        return (
          <Page {...props} user={user} />
        )
      } else {
        return <Redirect to="{= onAuthFailedRedirectTo =}" />
      }
    } else if (isLoading) {
      return <span>Loading...</span>
    } else if (isError) {
      return <span>An error ocurred. Please refresh the page.</span>
    } else {
      return <span>An unknown error ocurred. Please refresh the page.</span>
    }
  }
}

export default createAuthRequiredPage

