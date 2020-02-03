{{={= =}=}}
import _ from 'lodash'
import React from 'react'
import PropTypes from 'prop-types'
import { connect } from 'react-redux'

import Paper from '@material-ui/core/Paper'
import Table from '@material-ui/core/Table'
import TableBody from '@material-ui/core/TableBody'
import TableCell from '@material-ui/core/TableCell'
import TableHead from '@material-ui/core/TableHead'
import TableRow from '@material-ui/core/TableRow'
import Checkbox from '@material-ui/core/Checkbox'
import TextField from '@material-ui/core/TextField'
import ClickAwayListener from '@material-ui/core/ClickAwayListener'

import * as {= entityLowerName =}State from '../state'
import * as {= entityLowerName =}Actions from '../actions'

import {= entityClassName =} from '../{= entityClassName =}'


export class {= listName =} extends React.Component {
  static propTypes = {
    editable: PropTypes.bool,
    filter: PropTypes.func
  }

  state = {
    {= entityBeingEditedStateVar =}: null
  }

  update{= entityName =}Field = (fieldName, newFieldValue, {= entityLowerName =}) => {
    const updated{= entityName =} = new {= entityClassName =}(
      { ...{= entityLowerName =}.toData(), [fieldName]: newFieldValue }
    )
    this.props.update{= entityName =}({= entityLowerName =}.id, updated{= entityName =})
  }

  setAsBeingEdited = {= entityLowerName =} => this.setState({
    {= entityBeingEditedStateVar =}: {= entityLowerName =}.id
  })

  isBeingEdited = {= entityLowerName =} =>
    {= entityLowerName =}.id === this.state.{= entityBeingEditedStateVar =}

  finishEditing = {= entityLowerName =} => {
    if ({= entityLowerName =}.id === this.state.{= entityBeingEditedStateVar =})
      this.setState({ {= entityBeingEditedStateVar =}: null })
  }

  {=! Render "render" functions for each field, if provided =}
  {=# listFields =}
  {=# render =}
  {= renderFnName =} =
    {=& render =}
  {=/ render =}
  {=/ listFields =}
  
  render() {
    const {= entityLowerName =}ListToShow = this.props.filter ?
      {=! TODO(matija): duplication, we could extract entityLowerName_List =}
      this.props.{= entityLowerName =}List.filter(this.props.filter) :
      this.props.{= entityLowerName =}List

    return (
      <div style={ { margin: '20px' } }>
        <Paper>
          <Table>
            <TableHead>
              <TableRow>
                {=# listFields =}
                {=# boolean =}
                  <TableCell>{= name =}</TableCell>
                {=/ boolean =}
                {=# string =}
                  <TableCell>{= name =}</TableCell>
                {=/ string =}
                {=/ listFields =}
              </TableRow>
            </TableHead>

            <TableBody>
              {{= entityLowerName =}ListToShow.map(({= entityLowerName =}) => (
                <TableRow key={{= entityLowerName =}.id}>
                  {=# listFields =}
                  {=# boolean =}
                    <TableCell>
                      <Checkbox
                        checked={{= entityLowerName =}.{= name =}}
                        color="default"
                        inputProps={{
                          'aria-label': 'checkbox'
                        }}
                        disabled={!this.props.editable}
                        onChange={e => this.update{= entityName =}Field(
                          '{= name =}', e.target.checked, {= entityLowerName =}
                        )}
                      />
                    </TableCell>
                  {=/ boolean =}
                  {=# string =}
                    <ClickAwayListener onClickAway={() => this.finishEditing({= entityLowerName =}) }>
                      <TableCell
                        onDoubleClick={() => this.setAsBeingEdited({= entityLowerName =})}
                      >
                        {this.props.editable && this.isBeingEdited({= entityLowerName =}) ? (
                          <TextField
                            value={{= entityLowerName =}.{= name =}}
                            onChange={e => this.update{= entityName =}Field(
                              '{= name =}', e.target.value, {= entityLowerName =}
                            )}
                          />
                        ) : (
                          {=# render =}
                          this.{= renderFnName =}({= entityLowerName =})
                          {=/ render =}
                          {=^ render =}
                          {= entityLowerName =}.{= name =}
                          {=/ render =}
                        )}
                      </TableCell>
                    </ClickAwayListener>
                  {=/ string =}
                  {=/ listFields =}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Paper>
      </div>
    )
  }
}

export default connect(state => ({
  // Selectors
  {= entityLowerName =}List: {= entityLowerName =}State.selectors.all(state)
}), {
  // Actions
  update{= entityName =}: {= entityLowerName =}Actions.update
})({= listName =})
