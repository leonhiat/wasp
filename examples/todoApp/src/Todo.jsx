import React from 'react'

import Task from '@wasp/entities/task/Task'
import NewTaskForm from '@wasp/entities/task/components/NewTaskForm'
import TaskList from '@wasp/entities/task/components/TaskList'

import * as config from './config'

const TASK_FILTER_TYPES = Object.freeze({
  ALL: 'all',
  ACTIVE: 'active',
  COMPLETED: 'completed'
})

const TASK_FILTERS = Object.freeze({
  [TASK_FILTER_TYPES.ALL]: null,
  [TASK_FILTER_TYPES.ACTIVE]: task => !task.isDone,
  [TASK_FILTER_TYPES.COMPLETED]: task => task.isDone
})

export default class Todo extends React.Component {

  state = {
    taskFilterName: TASK_FILTER_TYPES.ALL
  }

  toggleIsDoneForAllTasks = () => {
    const areAllDone = this.props.taskList.every(t => t.isDone)
    {/* TODO: This feels clumsy / complicated. Is there a better way than using id (maybe not)?
       Should we consider passing just data to update, not the whole object, so we don't have to
       create new object here? Maybe we can change this update, or have a second update method. */}
    this.props.taskList.map(
      (t) => this.props.updateTask(t.id, new Task ({ ...t.toData(), isDone: !areAllDone }))
    )
  }

  deleteCompletedTasks = () => {
    this.props.taskList.map((t) => { if (t.isDone) this.props.removeTask(t.id) })
  }

  TaskFilterButton = ({ filterType, label }) => (
    <button
      className={'filter ' + (this.state.taskFilterName === filterType ? 'selected' : '')}
      onClick={() => this.setState({ taskFilterName: filterType })}
    >
      {label}
    </button>
  )

  isAnyTaskCompleted = () => this.props.taskList.some(t => t.isDone)

  isThereAnyTask = () => this.props.taskList.length > 0

  render = () => {
    return (
      <div className="mainContainer">
        <h1> { config.appName } </h1>

        <div className="contentContainer">
          <div className="toggleAndInput">
            <button 
              disabled={!this.isThereAnyTask()}
              className="toggleButton"
              onClick={this.toggleIsDoneForAllTasks}>
                ✓
            </button>

            <NewTaskForm
              className="newTaskForm"
              onCreate={task => this.props.addTask(task)}
              submitButtonLabel={'Create new task'}
            />
          </div>

          <TaskList
            editable
            filter={TASK_FILTERS[this.state.taskFilterName]}
          />
        </div>

        { this.isThereAnyTask() && (
            <div className="footer">
              <div className="footer__itemsLeft">
                { this.props.taskList.filter(task => !task.isDone).length } items left
              </div>

              <div className="footer__filters">
                <this.TaskFilterButton filterType={TASK_FILTER_TYPES.ALL} label="All" />
                <this.TaskFilterButton filterType={TASK_FILTER_TYPES.ACTIVE} label="Active" />
                <this.TaskFilterButton filterType={TASK_FILTER_TYPES.COMPLETED} label="Completed" />
              </div>

              <div className="footer__clearCompleted">
                  <button
                    className={this.isAnyTaskCompleted() ? '' : 'hidden' }
                    onClick={this.deleteCompletedTasks}>
                    Clear completed
                  </button>
              </div>
            </div>
          )
        }

      </div>
    )
  }
}
