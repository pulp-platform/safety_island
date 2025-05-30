

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_PROCESSES 5

typedef struct {
    int id;
    char name[32];
    int cpu;        // %
    int memory;     // MB
    char priority[16];
    char status[16];
    int isolation;  // 1: ON, 0: OFF
} Process;

void clearScreen() {
    printf("\033[H\033[J"); // ANSI escape to clear terminal
}

void printSystemStats(int cpu, int memory, int disk) {
    printf("=== SYSTEM STATS ===\n");
    printf("CPU Usage:    %d%%\n", cpu);
    printf("Memory Usage: %dMB\n", memory);
    printf("Disk Usage:   %d%%\n", disk);
    printf("====================\n\n");
}

void printProcesses(Process processes[], int count) {
    printf("ID | Name     | CPU(%%) | Mem(MB) | Priority | Status  | Isolation\n");
    printf("---------------------------------------------------------------\n");
    for (int i = 0; i < count; i++) {
        printf("%2d | %-8s | %6d | %7d | %-8s | %-7s | %s\n",
            processes[i].id,
            processes[i].name,
            processes[i].cpu,
            processes[i].memory,
            processes[i].priority,
            processes[i].status,
            processes[i].isolation ? "ON" : "OFF");
    }
    printf("\n");
}

void toggleIsolation(Process processes[], int id, int count) {
    for (int i = 0; i < count; i++) {
        if (processes[i].id == id) {
            processes[i].isolation = !processes[i].isolation;
            printf("Process %d isolation %s.\n", id, processes[i].isolation ? "ENABLED" : "DISABLED");
            return;
        }
    }
    printf("No process found with ID %d.\n", id);
}

int main() {
    Process processes[MAX_PROCESSES] = {
        {1, "Chrome", 25, 150, "High", "Running", 0},
        {2, "VSCode", 20, 120, "Medium", "Running", 0},
        {3, "Terminal", 5, 50, "Low", "Idle", 0},
        {4, "Slack", 10, 80, "Low", "Running", 0},
        {5, "Docker", 40, 200, "High", "Running", 0}
    };

    int cpu = 45;     // Mock CPU usage
    int memory = 512; // Mock memory usage
    int disk = 68;    // Mock disk usage

    int choice;

    while (1) {
        clearScreen();
        printSystemStats(cpu, memory, disk);
        printProcesses(processes, MAX_PROCESSES);

        printf("Options:\n");
        printf("1. Toggle Isolation\n");
        printf("2. Refresh\n");
        printf("0. Exit\n");
        printf("Enter choice: ");
        scanf("%d", &choice);

        if (choice == 0) {
            break;
        } else if (choice == 1) {
            int pid;
            printf("Enter Process ID to toggle isolation: ");
            scanf("%d", &pid);
            toggleIsolation(processes, pid, MAX_PROCESSES);
            sleep(2); // Wait before refresh
        }
    }

    printf("Exiting...\n");
    return 0;
}
