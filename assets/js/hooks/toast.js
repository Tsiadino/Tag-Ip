const Toast = {
  mounted() {
    this.handleEvent("show_toast", ({ type, message }) => {
      this.showToast(type, message)
    })
  },

  showToast(type, message) {
    const container = this.getToastContainer()
    
    const toast = document.createElement("div")
    toast.className = "animate-slide-in-right"
    
    const { bgColor, textColor, closeColor } = this.getColorsByType(type)
    const iconName = type === "success" 
      ? "hero-check-circle" 
      : type === "error" 
      ? "hero-exclamation-circle" 
      : "hero-information-circle"
    
    toast.innerHTML = `
      <div class="pointer-events-auto flex items-center gap-3 px-4 py-3 rounded-lg border ${bgColor} shadow-lg">
        <svg class="w-5 h-5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          ${this.getIconSVG(iconName)}
        </svg>
        <p class="text-sm font-medium ${textColor}">${message}</p>
        <button class="ml-auto ${closeColor} text-lg leading-none font-bold">
          ×
        </button>
      </div>
    `
    
    const closeBtn = toast.querySelector("button")
    closeBtn.addEventListener("click", () => {
      toast.classList.add("animate-slide-out-right")
      setTimeout(() => toast.remove(), 300)
    })
    
    container.appendChild(toast)
    
    setTimeout(() => {
      toast.classList.add("animate-slide-out-right")
      setTimeout(() => toast.remove(), 300)
    }, 5000)
  },

  getColorsByType(type) {
    const colors = {
      success: {
        bgColor: "bg-emerald-50 border-emerald-200",
        textColor: "text-emerald-800",
        closeColor: "text-emerald-400 hover:text-emerald-600"
      },
      error: {
        bgColor: "bg-red-50 border-red-200",
        textColor: "text-red-800",
        closeColor: "text-red-400 hover:text-red-600"
      },
      info: {
        bgColor: "bg-blue-50 border-blue-200",
        textColor: "text-blue-800",
        closeColor: "text-blue-400 hover:text-blue-600"
      }
    }
    return colors[type] || colors.info
  },

  getToastContainer() {
    let container = document.getElementById("toast-container")
    if (!container) {
      container = document.createElement("div")
      container.id = "toast-container"
      container.className = "fixed top-4 right-4 z-50 space-y-2"
      document.body.appendChild(container)
    }
    return container
  },

  getIconSVG(name) {
    const icons = {
      "hero-check-circle": `<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z" clip-rule="evenodd" />`,
      "hero-exclamation-circle": `<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd" />`,
      "hero-information-circle": `<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z" clip-rule="evenodd" />`
    }
    return icons[name] || icons["hero-information-circle"]
  }
}

export default Toast
