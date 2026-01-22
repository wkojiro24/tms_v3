import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect () {
    const numberOfGroups = 3
    const groups = new vis.DataSet()
    for (let i = 0; i < numberOfGroups; i++) {
      groups.add({ id: i, content: `Truck ${i}` })
    }
  }
}
